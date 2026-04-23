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
        groupBy     = req.Group_By__c;
        generatedDate = Date.today().format();

        // Load subscription data from staging lines
        groups    = DocGenService.loadGroupsFromStaging(requestId);
        grandTotal = 0;
        for (DocGenGroupWrapper g : groups) {
            grandTotal += g.groupTotal;
        }

        // Resolve account name from first selected contract
        List<Id> contractIds = (List<Id>) JSON.deserialize(
            req.Contract_Ids__c, List<Id>.class);
        List<Contract> contracts = [
            SELECT Account.Name FROM Contract WHERE Id = :contractIds[0] LIMIT 1
        ];
        accountName = contracts.isEmpty() ? '' : contracts[0].Account.Name;

        // Read live template header/footer from CPQ at render time.
        // Dynamic SOQL avoids compile errors if CPQ field names differ across package versions.
        // Any unknown merge field patterns degrade gracefully (left blank).
        if (String.isNotBlank(req.Template_Id__c)) {
            try {
                String tid = String.escapeSingleQuotes(req.Template_Id__c);
                List<SObject> templates = Database.query(
                    'SELECT SBQQ__HeaderContent__c, SBQQ__FooterContent__c ' +
                    'FROM SBQQ__QuoteTemplate__c WHERE Id = \'' + tid + '\' LIMIT 1'
                );
                if (!templates.isEmpty()) {
                    String rawHeader = (String) templates[0].get('SBQQ__HeaderContent__c');
                    String rawFooter = (String) templates[0].get('SBQQ__FooterContent__c');

                    Map<String, String> mergeValues = buildMergeMap(accountName);
                    templateHeader = DocGenService.substituteMergeFields(rawHeader, mergeValues);
                    templateFooter = DocGenService.substituteMergeFields(rawFooter, mergeValues);
                }
            } catch (Exception e) {
                // CPQ template fields unavailable in this package version — render without header/footer
                templateHeader = '';
                templateFooter = '';
            }
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
