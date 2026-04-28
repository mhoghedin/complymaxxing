public class ContractRenewalScheduler implements Schedulable {
    @TestVisible static List<Contract> testContracts;

    public void execute(SchedulableContext ctx) {
        ContractRenewalConfig config = ContractRenewalConfig.load();

        List<Contract> contracts = testContracts != null
            ? testContracts
            : queryContracts(config);

        if (contracts.isEmpty()) return;

        Set<Id> accountIds = new Set<Id>();
        Set<Date> expirationDates = new Set<Date>();
        for (Contract c : contracts) {
            accountIds.add(c.AccountId);
            expirationDates.add(c.Expiration_Date__c);
        }

        Map<String, Id> existingOppByGroupKey = new Map<String, Id>();
        for (Contract c : [
            SELECT AccountId, Expiration_Date__c, SBQQ__RenewalOpportunity__c
            FROM Contract
            WHERE AccountId IN :accountIds
            AND Expiration_Date__c IN :expirationDates
            AND SBQQ__RenewalOpportunity__c != null
        ]) {
            String key = c.AccountId + '_' + String.valueOf(c.Expiration_Date__c);
            if (!existingOppByGroupKey.containsKey(key)) {
                existingOppByGroupKey.put(key, c.SBQQ__RenewalOpportunity__c);
            }
        }

        Map<String, List<Contract>> grouped = ContractRenewalService.groupContracts(contracts);

        List<List<Id>> groups = new List<List<Id>>();
        List<Id> existingOpps = new List<Id>();
        List<Id> masterContractIds = new List<Id>();

        for (String key : grouped.keySet()) {
            List<Contract> groupContracts = grouped.get(key);
            List<Id> ids = new List<Id>();
            Id masterId = null;
            for (Contract c : groupContracts) {
                if (c.SBQQ__MasterContract__c) {
                    masterId = c.Id;
                } else {
                    ids.add(c.Id);
                }
            }
            if (masterId != null) {
                ids.add(0, masterId);
            } else {
                masterId = ids[0];
            }
            groups.add(ids);
            existingOpps.add(existingOppByGroupKey.get(key));
            masterContractIds.add(masterId);
        }

        System.enqueueJob(new ContractRenewalQueueable(groups, existingOpps, masterContractIds, 0));
    }

    @TestVisible
    static List<Contract> queryContracts(ContractRenewalConfig config) {
        Integer queryLimit = config.queryLimit;
        return [
            SELECT Id, AccountId, Expiration_Date__c, SBQQ__RenewalOpportunity__c, SBQQ__MasterContract__c
            FROM Contract
            WHERE Contract_Status2__c = 'Contracted'
            AND SBQQ__RenewalOpportunity__c = null
            AND Expiration_Date__c != null
            LIMIT :queryLimit
        ];
    }
}
