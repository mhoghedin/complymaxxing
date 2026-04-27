public class CpqRenewalApi implements IRenewalApi {
    // SBQQ.ServiceRouter is the globally accessible CPQ API entry point.
    // ContractRenewer takes one contract at a time and returns a quote model JSON.
    // We merge all contracts' line items in memory and save once — one opp, one quote.
    public Id renewContracts(List<Id> contractIds) {
        Map<String, Object> masterQuote = null;

        for (Id contractId : contractIds) {
            String quoteJson = SBQQ.ServiceRouter.load(
                'SBQQ.ContractManipulationAPI.ContractRenewer',
                contractId,
                null
            );
            if (String.isBlank(quoteJson)) continue;
            Map<String, Object> quoteData =
                (Map<String, Object>) JSON.deserializeUntyped(quoteJson);

            if (masterQuote == null) {
                masterQuote = quoteData;
            } else {
                // Merge this contract's renewal lines into the master quote
                List<Object> masterLines = (List<Object>) masterQuote.get('lineItems');
                List<Object> newLines    = (List<Object>) quoteData.get('lineItems');
                if (masterLines != null && newLines != null) {
                    masterLines.addAll(newLines);
                }
            }
        }

        if (masterQuote == null) {
            throw new ContractRenewalService.ContractRenewalException(
                'ContractRenewer returned no quote model for any contract in this group');
        }

        // Save the merged quote — CPQ creates the renewal Opportunity and Quote in the org
        String savedJson = SBQQ.ServiceRouter.save(
            'SBQQ.QuoteAPI.QuoteSaver',
            JSON.serialize(masterQuote),
            null
        );

        Map<String, Object> savedQuote =
            (Map<String, Object>) JSON.deserializeUntyped(savedJson);
        String quoteId = (String) savedQuote.get('Id');

        if (String.isBlank(quoteId)) {
            throw new ContractRenewalService.ContractRenewalException(
                'QuoteSaver did not return a Quote ID after saving renewal quote');
        }

        // Read back the Opportunity the saved quote is linked to
        List<SBQQ__Quote__c> quotes = [
            SELECT SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (quotes.isEmpty() || quotes[0].SBQQ__Opportunity2__c == null) {
            throw new ContractRenewalService.ContractRenewalException(
                'Could not find Opportunity linked to saved renewal quote ' + quoteId);
        }

        return quotes[0].SBQQ__Opportunity2__c;
    }
}
