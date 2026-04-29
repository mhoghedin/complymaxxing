public class ContractRenewalService {
    @TestVisible static IRenewalApi renewApi = new CpqRenewalApi();

    public class ContractRenewalException extends Exception {}

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

    public static void processGroup(List<Id> contractIds, Id existingRenewalOppId, Id masterContractId) {
        Id newOppId = renewApi.renewContracts(contractIds, masterContractId);

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
                toUpdate.add(new Contract(Id = cId, SBQQ__RenewalOpportunity__c = finalOppId));
            }
            update toUpdate;
        }
    }

    @TestVisible
    static void reparentQuote(Id newOppId, Id targetOppId) {
        Id newQuoteId;
        try {
            List<SObject> newQuotes = Database.query(
                'SELECT Id FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c = :newOppId LIMIT 1'
            );
            if (newQuotes.isEmpty()) {
                delete new Opportunity(Id = newOppId);
                return;
            }

            SObject newQuote = newQuotes[0];
            newQuoteId = (Id) newQuote.get('Id');
            newQuote.put('SBQQ__Opportunity2__c', targetOppId);
            update newQuote;
        } catch (DmlException e) {
            throw new ContractRenewalException(
                'Failed to re-parent CPQ quote from opp ' + newOppId +
                ' to ' + targetOppId + ': ' + e.getMessage()
            );
        }

        // Schedule cleanup 2 minutes out — gives CPQ's calculation sequence
        // time to fully settle before we demote the old primary quote
        if (newQuoteId != null) {
            DateTime runAt = DateTime.now().addMinutes(2);
            String cron = runAt.second() + ' ' + runAt.minute() + ' ' + runAt.hour()
                + ' ' + runAt.day() + ' ' + runAt.month() + ' ? ' + runAt.year();
            System.schedule('QuotePrimaryCleanup_' + newQuoteId, cron,
                new QuotePrimaryCleanup(targetOppId, newQuoteId));
        }

        try {
            delete new Opportunity(Id = newOppId);
        } catch (DmlException e) {
            // Best-effort — quote is already on the right opp, contracts will still be stamped
        }
    }
}
