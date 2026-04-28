public class CpqRenewalApi implements IRenewalApi {
    public Id renewContracts(List<Id> contractIds, Id masterContractId) {
        Map<String, Object> renewalContext = new Map<String, Object>{
            'masterContractId' => masterContractId,
            'renewedContracts' => contractIds
        };

        String quoteJson = SBQQ.ServiceRouter.load(
            'SBQQ.ContractManipulationAPI.ContractRenewer',
            masterContractId,
            JSON.serialize(renewalContext)
        );

        if (String.isBlank(quoteJson)) {
            throw new ContractRenewalService.ContractRenewalException(
                'ContractRenewer returned no quote model for contracts: ' + contractIds);
        }

        String savedJson = SBQQ.ServiceRouter.save(
            'SBQQ.QuoteAPI.QuoteSaver',
            quoteJson,
            null
        );

        if (String.isBlank(savedJson)) {
            throw new ContractRenewalService.ContractRenewalException(
                'QuoteSaver returned no response when saving renewal quote');
        }

        Map<String, Object> savedQuote =
            (Map<String, Object>) JSON.deserializeUntyped(savedJson);
        String quoteId = (String) savedQuote.get('Id');

        if (String.isBlank(quoteId)) {
            throw new ContractRenewalService.ContractRenewalException(
                'QuoteSaver did not return a Quote ID after saving renewal quote');
        }

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
