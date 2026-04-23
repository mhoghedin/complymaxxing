public class DocGenController {

    @TestVisible static final Integer MAX_SUBSCRIPTION_LINES = 2000;

    public class GroupOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        GroupOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<GroupOption> getGroupByOptions() {
        List<GroupOption> opts = new List<GroupOption>();
        for (DocGen_Group_Option__mdt opt : [
            SELECT MasterLabel, Field_API_Name__c
            FROM DocGen_Group_Option__mdt
            ORDER BY Sort_Order__c
        ]) {
            opts.add(new GroupOption(opt.MasterLabel, opt.Field_API_Name__c));
        }
        return opts;
    }

    @AuraEnabled(cacheable=false)
    public static List<SObject> getAvailableTemplates() {
        return Database.query(
            'SELECT Id, Name FROM SBQQ__QuoteTemplate__c ORDER BY Name'
        );
    }

    @AuraEnabled(cacheable=false)
    public static List<Contract> getContracts(String searchTerm) {
        String likePattern = '%' + (String.isBlank(searchTerm) ? '' : searchTerm.trim()) + '%';
        return [
            SELECT Id, Name, AccountId, Account.Name,
                   Status, StartDate, Expiration_Date__c
            FROM Contract
            WHERE (Name LIKE :likePattern OR Account.Name LIKE :likePattern)
            AND Status != 'Draft'
            ORDER BY Account.Name, Name
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=false)
    public static List<DocGenGroupWrapper> getSubscriptionPreview(
            List<Id> contractIds, String groupByField) {

        if (mockPreviewResult != null) return mockPreviewResult;
        List<String> allGroupFields = validateAndGetGroupingFields(groupByField);
        List<SBQQ__Subscription__c> subs = DocGenService.querySubscriptions(contractIds, allGroupFields);
        enforceLineLimit(subs.size());
        return DocGenService.normalizeAndGroup(subs, groupByField);
    }

    @AuraEnabled
    public static String generateDocument(
            List<Id> contractIds, String groupByField, String templateId) {

        List<String> allGroupFields = validateAndGetGroupingFields(groupByField);
        List<SBQQ__Subscription__c> subs = mockSubscriptions != null
            ? mockSubscriptions
            : DocGenService.querySubscriptions(contractIds, allGroupFields);

        if (subs.isEmpty()) {
            throw new AuraHandledException(
                'No year-1 subscriptions found on the selected contracts.');
        }

        enforceLineLimit(subs.size());

        Set<Id> accountIds = new Set<Id>();
        for (SBQQ__Subscription__c s : subs) {
            accountIds.add(s.SBQQ__Contract__r.AccountId);
        }
        if (accountIds.size() > 1) {
            throw new AuraHandledException(
                'Selected contracts must belong to the same account.');
        }

        String accountName = subs[0].SBQQ__Contract__r.Account.Name;
        List<DocGenGroupWrapper> groups = DocGenService.normalizeAndGroup(subs, groupByField);
        Id requestId = DocGenService.buildStagingRecord(
            contractIds, groups, groupByField, templateId);

        try {
            return DocGenService.renderAndSave(requestId, contractIds, accountName);
        } finally {
            DocGenService.cleanupStaging(requestId);
        }
    }

    // Validates groupByField against CMT whitelist and returns all configured field names
    // in a single query so the subscription SELECT includes every possible grouping field.
    private static List<String> validateAndGetGroupingFields(String groupByField) {
        List<String> fields = new List<String>();
        Boolean fieldFound  = false;
        for (DocGen_Group_Option__mdt opt : [
            SELECT Field_API_Name__c FROM DocGen_Group_Option__mdt
        ]) {
            if (String.isNotBlank(opt.Field_API_Name__c)) {
                fields.add(opt.Field_API_Name__c);
                if (opt.Field_API_Name__c == groupByField) {
                    fieldFound = true;
                }
            }
        }
        if (!fieldFound) {
            throw new AuraHandledException(
                'Grouping option "' + groupByField +
                '" is not configured in DocGen Group Option metadata.');
        }
        return fields;
    }

    private static void enforceLineLimit(Integer count) {
        if (count > MAX_SUBSCRIPTION_LINES) {
            throw new AuraHandledException(
                'Selection contains ' + count + ' subscription lines. ' +
                'Maximum supported per document is ' + MAX_SUBSCRIPTION_LINES + '. ' +
                'Please select fewer contracts.');
        }
    }

    @TestVisible static List<DocGenGroupWrapper> mockPreviewResult;
    @TestVisible static List<SBQQ__Subscription__c> mockSubscriptions;
}
