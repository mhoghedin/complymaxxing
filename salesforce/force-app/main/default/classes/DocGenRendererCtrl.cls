public class DocGenRendererCtrl {
    public String templateHeader  { get; private set; }
    public String templateFooter  { get; private set; }
    public String groupBy         { get; private set; }
    public String accountName     { get; private set; }
    public String generatedDate   { get; private set; }
    public Decimal grandTotal     { get; private set; }
    public List<DocGenGroupWrapper> groups { get; private set; }

    public DocGenRendererCtrl() {
        Id requestId = (Id) ApexPages.currentPage().getParameters().get('requestId');
        if (requestId == null) {
            groups = new List<DocGenGroupWrapper>();
            return;
        }

        DocGen_Request__c req = [
            SELECT Template_Id__c, Group_By__c, Contract_Ids__c
            FROM DocGen_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];
        groupBy       = req.Group_By__c;
        generatedDate = Date.today().format();

        groups    = DocGenService.loadGroupsFromStaging(requestId);
        grandTotal = 0;
        for (DocGenGroupWrapper g : groups) {
            grandTotal += g.groupTotal;
        }

        List<Id> contractIds = (List<Id>) JSON.deserialize(
            req.Contract_Ids__c, List<Id>.class);
        List<Contract> contracts = [
            SELECT Account.Name FROM Contract WHERE Id = :contractIds[0] LIMIT 1
        ];
        accountName = contracts.isEmpty() ? '' : contracts[0].Account.Name;

        if (String.isNotBlank(req.Template_Id__c)) {
            loadTemplateContent(req.Template_Id__c, accountName);
        }
    }

    // Reads header/footer field names from DocGen_Template_Field__mdt, then queries
    // the chosen CPQ template at runtime. Adding a new CMT record (e.g. Section = 'Header',
    // Field_API_Name = 'Custom_Header__c') is all that's needed to switch fields — no code change.
    private void loadTemplateContent(String templateId, String account) {
        Map<String, String> sectionToField = new Map<String, String>();
        for (DocGen_Template_Field__mdt rec : [
            SELECT Section__c, Field_API_Name__c
            FROM DocGen_Template_Field__mdt
            WHERE Section__c IN ('Header', 'Footer')
            AND Field_API_Name__c != null
        ]) {
            sectionToField.put(rec.Section__c, rec.Field_API_Name__c);
        }

        if (sectionToField.isEmpty()) return;

        // Build SELECT from CMT-defined fields only — no hardcoded CPQ field names
        List<String> selectFields = new List<String>(sectionToField.values());
        String tid  = String.escapeSingleQuotes(templateId);
        String soql = 'SELECT ' + String.join(selectFields, ', ') +
                      ' FROM SBQQ__QuoteTemplate__c WHERE Id = \'' + tid + '\' LIMIT 1';

        try {
            List<SObject> results = Database.query(soql);
            if (results.isEmpty()) return;

            SObject tmpl = results[0];
            Map<String, String> mergeValues = buildMergeMap(account);

            String headerField = sectionToField.get('Header');
            String footerField = sectionToField.get('Footer');

            if (headerField != null) {
                templateHeader = DocGenService.substituteMergeFields(
                    (String) tmpl.get(headerField), mergeValues);
            }
            if (footerField != null) {
                templateFooter = DocGenService.substituteMergeFields(
                    (String) tmpl.get(footerField), mergeValues);
            }
        } catch (Exception e) {
            // Field unavailable in this CPQ version — fallback header/footer rendered by VF
            templateHeader = '';
            templateFooter = '';
        }
    }

    private static Map<String, String> buildMergeMap(String accountName) {
        String today   = Date.today().format();
        String repName = UserInfo.getName();
        return new Map<String, String>{
            '{!Quote.Account.Name}'    => accountName,
            '{Account.Name}'           => accountName,
            '{!Quote.ExpirationDate}'  => today,
            '{Quote.ExpirationDate}'   => today,
            '{!Quote.GeneratedDate}'   => today,
            '{Quote.GeneratedDate}'    => today,
            '{SalesRep.Name}'          => repName,
            '{!User.Name}'             => repName,
            '{!Quote.Name}'            => 'Subscription Summary',
            '{Quote.Name}'             => 'Subscription Summary',
            '{!Quote.Number}'          => 'DOC-' + today
        };
    }
}
