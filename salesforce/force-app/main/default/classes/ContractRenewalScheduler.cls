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
        Map<String, List<Id>> priorContractsByGroupKey = new Map<String, List<Id>>();
        Map<String, Id> priorMasterByGroupKey = new Map<String, Id>();

        for (Contract c : [
            SELECT Id, AccountId, Expiration_Date__c, SBQQ__RenewalOpportunity__c, SBQQ__MasterContract__c
            FROM Contract
            WHERE AccountId IN :accountIds
            AND Expiration_Date__c IN :expirationDates
            AND SBQQ__RenewalOpportunity__c != null
        ]) {
            String key = c.AccountId + '_' + String.valueOf(c.Expiration_Date__c);
            if (!existingOppByGroupKey.containsKey(key)) {
                existingOppByGroupKey.put(key, c.SBQQ__RenewalOpportunity__c);
                priorContractsByGroupKey.put(key, new List<Id>());
            }
            priorContractsByGroupKey.get(key).add(c.Id);
            if (c.SBQQ__MasterContract__c) {
                priorMasterByGroupKey.put(key, c.Id);
            }
        }

        Map<String, List<Contract>> grouped = ContractRenewalService.groupContracts(contracts);

        List<List<Id>> groups = new List<List<Id>>();
        List<Id> existingOpps = new List<Id>();
        List<Id> masterContractIds = new List<Id>();

        for (String key : grouped.keySet()) {
            List<Contract> groupContracts = grouped.get(key);
            List<Id> masterFirst = new List<Id>();
            List<Id> others = new List<Id>();
            Id masterId = priorMasterByGroupKey.get(key);

            // Slot already-renewed contracts into master/others
            if (priorContractsByGroupKey.containsKey(key)) {
                for (Id priorId : priorContractsByGroupKey.get(key)) {
                    if (priorId == masterId) {
                        masterFirst.add(priorId);
                    } else {
                        others.add(priorId);
                    }
                }
            }

            // Slot new contracts in, detecting master if not already known
            for (Contract c : groupContracts) {
                if (c.SBQQ__MasterContract__c) {
                    if (masterId == null) masterId = c.Id;
                    masterFirst.add(c.Id);
                } else {
                    others.add(c.Id);
                }
            }

            List<Id> ids = new List<Id>();
            ids.addAll(masterFirst);
            ids.addAll(others);
            if (masterId == null && !ids.isEmpty()) masterId = ids[0];

            groups.add(ids);
            existingOpps.add(existingOppByGroupKey.get(key));
            masterContractIds.add(masterId);
        }

        // Must run here: Apex forbids DML before a callout in the same transaction
        List<Contract> toReset = new List<Contract>();
        for (Integer i = 0; i < groups.size(); i++) {
            if (existingOpps.get(i) != null) {
                for (Id cId : groups.get(i)) {
                    toReset.add(new Contract(
                        Id = cId,
                        SBQQ__RenewalQuoted__c = false,
                        SBQQ__RenewalOpportunity__c = null
                    ));
                }
            }
        }
        if (!toReset.isEmpty()) update toReset;

        System.enqueueJob(new ContractRenewalQueueable(groups, existingOpps, masterContractIds, 0));
    }

    @TestVisible
    static List<Contract> queryContracts(ContractRenewalConfig config) {
        return [
            SELECT Id, AccountId, Expiration_Date__c, SBQQ__RenewalOpportunity__c, SBQQ__MasterContract__c
            FROM Contract
            WHERE Contract_Status2__c = 'Contracted'
            AND SBQQ__RenewalOpportunity__c = null
            AND Expiration_Date__c != null
            LIMIT :config.queryLimit
        ];
    }
}
