public class DocGenService {

    // Query all year-1 subscriptions. additionalFields are CMT-defined grouping fields
    // added to the SELECT so sub.get(fieldApiName) works for any CMT option.
    public static List<SBQQ__Subscription__c> querySubscriptions(
            List<Id> contractIds, List<String> additionalFields) {

        Set<String> fields = new Set<String>{
            'Id', 'SBQQ__ProductName__c', 'SBQQ__Product__c',
            'SBQQ__Quantity__c', 'SBQQ__CustomerPrice__c', 'SBQQ__RegularPrice__c',
            'SBQQ__StartDate__c', 'SBQQ__EndDate__c',
            'SiteNamelabel__c', 'SegmentIndex__c',
            'SBQQ__Contract__r.Name',
            'SBQQ__Contract__r.AccountId',
            'SBQQ__Contract__r.Account.Name'
        };

        if (additionalFields != null) {
            for (String f : additionalFields) {
                // Field API names: alphanumeric + underscore only — guard against injection
                if (String.isNotBlank(f) && f.replaceAll('[a-zA-Z0-9_]', '').length() == 0) {
                    fields.add(f);
                }
            }
        }

        String soql =
            'SELECT ' + String.join(new List<String>(fields), ', ') +
            ' FROM SBQQ__Subscription__c' +
            ' WHERE SBQQ__Contract__c IN :contractIds' +
            ' AND SegmentIndex__c = 1' +
            ' ORDER BY SiteNamelabel__c, SBQQ__ProductName__c';

        return Database.query(soql);
    }

    // Group and normalize subscriptions. groupByField is the Subscription field API name.
    public static List<DocGenGroupWrapper> normalizeAndGroup(
            List<SBQQ__Subscription__c> subs, String groupByField) {

        Map<String, DocGenGroupWrapper> groupMap = new Map<String, DocGenGroupWrapper>();
        List<String> groupOrder = new List<String>();

        for (SBQQ__Subscription__c sub : subs) {
            String rawValue = (String) sub.get(groupByField);
            String key = String.isBlank(rawValue) ? 'Ungrouped' : rawValue;

            if (!groupMap.containsKey(key)) {
                groupMap.put(key, new DocGenGroupWrapper(key));
                groupOrder.add(key);
            }

            DocGenLineWrapper line = new DocGenLineWrapper(sub);
            DocGenGroupWrapper grp = groupMap.get(key);
            grp.lines.add(line);
            grp.groupTotal += (line.netPrice != null ? line.netPrice : 0)
                            * (line.quantity  != null ? line.quantity  : 1);
        }

        List<DocGenGroupWrapper> result = new List<DocGenGroupWrapper>();
        for (String key : groupOrder) {
            result.add(groupMap.get(key));
        }
        return result;
    }

    // Insert DocGen_Request__c + DocGen_Line__c staging records. Returns request Id.
    public static Id buildStagingRecord(
            List<Id> contractIds, List<DocGenGroupWrapper> groups,
            String groupBy, Id templateId) {

        DocGen_Request__c req = new DocGen_Request__c(
            Group_By__c    = groupBy,
            Template_Id__c = String.valueOf(templateId),
            Contract_Ids__c = JSON.serialize(contractIds),
            Requested_By__c = UserInfo.getUserId(),
            Created_At__c   = Datetime.now()
        );
        insert req;

        List<DocGen_Line__c> lines = new List<DocGen_Line__c>();
        Integer sortOrder = 0;
        for (DocGenGroupWrapper grp : groups) {
            for (DocGenLineWrapper ln : grp.lines) {
                lines.add(new DocGen_Line__c(
                    Request__c      = req.Id,
                    Group_Label__c  = grp.groupLabel,
                    Sort_Order__c   = sortOrder++,
                    Product_Name__c = ln.productName,
                    Quantity__c     = ln.quantity,
                    Net_Price__c    = ln.netPrice,
                    List_Price__c   = ln.listPrice,
                    Start_Date__c   = ln.startDate,
                    End_Date__c     = ln.endDate,
                    Site_Name__c    = ln.siteName,
                    Contract_Name__c = ln.contractName
                ));
            }
        }
        insert lines;
        return req.Id;
    }

    // Read staging lines back into grouped wrappers for VF rendering
    public static List<DocGenGroupWrapper> loadGroupsFromStaging(Id requestId) {
        List<DocGen_Line__c> lines = [
            SELECT Group_Label__c, Sort_Order__c, Product_Name__c,
                   Quantity__c, Net_Price__c, List_Price__c,
                   Start_Date__c, End_Date__c, Site_Name__c, Contract_Name__c
            FROM DocGen_Line__c
            WHERE Request__c = :requestId
            ORDER BY Sort_Order__c
        ];

        Map<String, DocGenGroupWrapper> groupMap = new Map<String, DocGenGroupWrapper>();
        List<String> groupOrder = new List<String>();

        for (DocGen_Line__c line : lines) {
            String label = line.Group_Label__c;
            if (!groupMap.containsKey(label)) {
                groupMap.put(label, new DocGenGroupWrapper(label));
                groupOrder.add(label);
            }
            DocGenLineWrapper w = new DocGenLineWrapper();
            w.productName  = line.Product_Name__c;
            w.siteName     = line.Site_Name__c;
            w.contractName = line.Contract_Name__c;
            w.quantity     = line.Quantity__c;
            w.netPrice     = line.Net_Price__c;
            w.listPrice    = line.List_Price__c;
            w.startDate    = line.Start_Date__c;
            w.endDate      = line.End_Date__c;

            DocGenGroupWrapper grp = groupMap.get(label);
            grp.lines.add(w);
            grp.groupTotal += (w.netPrice != null ? w.netPrice : 0)
                            * (w.quantity != null ? w.quantity  : 1);
        }

        List<DocGenGroupWrapper> result = new List<DocGenGroupWrapper>();
        for (String key : groupOrder) {
            result.add(groupMap.get(key));
        }
        return result;
    }

    // Replace common CPQ merge field patterns with real values from our data
    public static String substituteMergeFields(String html, Map<String, String> values) {
        if (String.isBlank(html)) return '';
        String result = html;
        for (String token : values.keySet()) {
            String val = values.get(token) != null ? values.get(token) : '';
            result = result.replace(token, val);
        }
        return result;
    }

    // Render the VF page to PDF, save as ContentVersion, link to each contract
    public static String renderAndSave(Id requestId, List<Id> contractIds, String accountName) {
        PageReference pdfPage = Page.DocGenRenderer;
        pdfPage.getParameters().put('requestId', requestId);

        Blob pdfContent = Test.isRunningTest()
            ? Blob.valueOf('PDF_TEST_PLACEHOLDER')
            : pdfPage.getContent();

        ContentVersion cv = new ContentVersion(
            Title         = 'Subscription Summary — ' + accountName + ' — ' + Date.today().format(),
            PathOnClient  = 'DocGen_SubscriptionSummary.pdf',
            VersionData   = pdfContent,
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id cId : contractIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = contentDocId,
                LinkedEntityId    = cId,
                ShareType         = 'V'
            ));
        }
        insert links;

        return '/sfc/servlet.shepherd/document/download/' + cv.Id;
    }

    // Delete staging records — always called in a finally block
    public static void cleanupStaging(Id requestId) {
        if (requestId == null) return;
        delete [SELECT Id FROM DocGen_Request__c WHERE Id = :requestId];
    }
}
