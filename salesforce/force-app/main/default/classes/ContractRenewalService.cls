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

        // CPQ's QuoteAfter requires a clean transaction, delay lets the calculation settle
        try {
            System.schedule('QuotePrimaryCleanup_' + newQuoteId, buildCron(SYNC_DELAY_MINUTES),
                new QuotePrimaryCleanup(targetOppId, newQuoteId));
        } catch (Exception ignored) {}

        try {
            delete new Opportunity(Id = newOppId);
        } catch (DmlException e) {
            // Best effort, quote is on the right opp regardless
        }
    }

    private static final Integer SYNC_DELAY_MINUTES = 2;

    private static String buildCron(Integer delayMinutes) {
        DateTime runAt = DateTime.now().addMinutes(delayMinutes);
        return runAt.second() + ' ' + runAt.minute() + ' ' + runAt.hour()
            + ' ' + runAt.day() + ' ' + runAt.month() + ' ? ' + runAt.year();
    }
}
