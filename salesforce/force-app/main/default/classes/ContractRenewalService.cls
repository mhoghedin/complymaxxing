public class ContractRenewalService {
    @TestVisible static IRenewalApi renewApi = new CpqRenewalApi();

    public static Map<String, List<Contract>> groupContracts(List<Contract> contracts) {
        Map<String, List<Contract>> groups = new Map<String, List<Contract>>();
        for (Contract c : contracts) {
            String key = c.AccountId + '_' + String.valueOf(c.Expiration_Date__c);
            if (!groups.containsKey(key)) {
                groups.put(key, new List<Contract>());
            }
            groups.get(key).add(c);
        }
        return groups;
    }

    // Returns the existing renewal opp for a group, or null if this is the first run.
    // Looks at contracts already processed in a prior job run — they have Renewal_Opportunity__c set.
    public static Id getExistingRenewalOpp(List<Contract> groupContracts) {
        for (Contract c : groupContracts) {
            if (c.Renewal_Opportunity__c != null) {
                return c.Renewal_Opportunity__c;
            }
        }
        return null;
    }

    public static void processGroup(List<Id> contractIds, Id existingRenewalOppId) {
        Id newOppId = renewApi.renewContracts(contractIds);

        Id finalOppId;
        if (existingRenewalOppId != null && newOppId != null && newOppId != existingRenewalOppId) {
            reparentQuote(newOppId, existingRenewalOppId);
            finalOppId = existingRenewalOppId;
        } else {
            finalOppId = newOppId;
        }

        if (finalOppId != null) {
            List<Contract> toUpdate = new List<Contract>();
            for (Id cId : contractIds) {
                toUpdate.add(new Contract(Id = cId, Renewal_Opportunity__c = finalOppId));
            }
            update toUpdate;
        }
    }

    // Dynamic SOQL avoids compile errors in orgs where CPQ is not yet installed.
    // In production with CPQ installed, this queries SBQQ__Quote__c normally.
    @TestVisible
    static void reparentQuote(Id newOppId, Id targetOppId) {
        try {
            List<SObject> quotes = Database.query(
                'SELECT Id FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c = :newOppId LIMIT 1'
            );
            if (!quotes.isEmpty()) {
                quotes[0].put('SBQQ__Opportunity2__c', targetOppId);
                update quotes[0];
            }
        } catch (System.QueryException e) {
            // CPQ not installed — skip quote re-parenting, deletion still proceeds
        }
        delete new Opportunity(Id = newOppId);
    }
}
