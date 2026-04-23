public class DocGenController {

    @AuraEnabled(cacheable=false)
    public static List<SObject> getAvailableTemplates() {
        // Dynamic SOQL keeps this safe in orgs where CPQ package version varies
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
            List<Id> contractIds, String groupBy) {

        if (mockPreviewResult != null) return mockPreviewResult;
        List<SBQQ__Subscription__c> subs = DocGenService.querySubscriptions(contractIds);
        return DocGenService.normalizeAndGroup(subs, groupBy);
    }

    @AuraEnabled
    public static String generateDocument(
            List<Id> contractIds, String groupBy, String templateId) {

        List<SBQQ__Subscription__c> subs = mockSubscriptions != null
            ? mockSubscriptions
            : DocGenService.querySubscriptions(contractIds);

        if (subs.isEmpty()) {
            throw new AuraHandledException(
                'No year-1 subscriptions found on the selected contracts.');
        }

        // All contracts must belong to the same account
        Set<Id> accountIds = new Set<Id>();
        for (SBQQ__Subscription__c s : subs) {
            accountIds.add(s.SBQQ__Contract__r.AccountId);
        }
        if (accountIds.size() > 1) {
            throw new AuraHandledException(
                'Selected contracts must belong to the same account.');
        }

        String accountName = subs[0].SBQQ__Contract__r.Account.Name;
        List<DocGenGroupWrapper> groups = DocGenService.normalizeAndGroup(subs, groupBy);
        Id requestId = DocGenService.buildStagingRecord(
            contractIds, groups, groupBy, templateId);

        try {
            return DocGenService.renderAndSave(requestId, contractIds, accountName);
        } finally {
            DocGenService.cleanupStaging(requestId);
        }
    }

    @TestVisible static List<DocGenGroupWrapper> mockPreviewResult;
    @TestVisible static List<SBQQ__Subscription__c> mockSubscriptions;
}
