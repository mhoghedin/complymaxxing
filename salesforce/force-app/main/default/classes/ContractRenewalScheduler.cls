public class ContractRenewalScheduler implements Schedulable {
    // Injected in tests to bypass the CPQ-field SOQL query
    @TestVisible static List<Contract> testContracts;

    public void execute(SchedulableContext ctx) {
        ContractRenewalConfig config = ContractRenewalConfig.load();

        List<Contract> contracts = testContracts != null
            ? testContracts
            : queryContracts(config);

        if (contracts.isEmpty()) return;

        // Second query: find existing renewal opps for these account/date combos
        // so we know which groups have already been partially processed
        Set<Id> accountIds = new Set<Id>();
        Set<Date> expirationDates = new Set<Date>();
        for (Contract c : contracts) {
            accountIds.add(c.AccountId);
            expirationDates.add(c.Expiration_Date__c);
        }

        Map<String, Id> existingOppByGroupKey = new Map<String, Id>();
        for (Contract c : [
            SELECT AccountId, Expiration_Date__c, Renewal_Opportunity__c
            FROM Contract
            WHERE AccountId IN :accountIds
            AND Expiration_Date__c IN :expirationDates
            AND Renewal_Opportunity__c != null
        ]) {
            String key = c.AccountId + '_' + String.valueOf(c.Expiration_Date__c);
            if (!existingOppByGroupKey.containsKey(key)) {
                existingOppByGroupKey.put(key, c.Renewal_Opportunity__c);
            }
        }

        Map<String, List<Contract>> grouped = ContractRenewalService.groupContracts(contracts);

        List<List<Id>> groups = new List<List<Id>>();
        List<Id> existingOpps = new List<Id>();

        for (String key : grouped.keySet()) {
            List<Id> ids = new List<Id>();
            for (Contract c : grouped.get(key)) {
                ids.add(c.Id);
            }
            groups.add(ids);
            existingOpps.add(existingOppByGroupKey.get(key));
        }

        System.enqueueJob(new ContractRenewalQueueable(groups, existingOpps, 0));
    }

    // queryLimit bounds heap usage. For very high volumes (10k+ contracts/run),
    // migrate the outer loop to a Database.Batchable.
    @TestVisible
    static List<Contract> queryContracts(ContractRenewalConfig config) {
        Integer queryLimit = config.queryLimit;
        return [
            SELECT Id, AccountId, Expiration_Date__c, Renewal_Opportunity__c
            FROM Contract
            WHERE Status = :config.finalizedStatus
            AND SBQQ__RenewalQuoted__c = false
            AND Expiration_Date__c != null
            LIMIT :queryLimit
        ];
    }
}
