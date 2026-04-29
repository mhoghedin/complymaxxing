public class CpqRenewalApi implements IRenewalApi {
    public Id renewContracts(List<Id> contractIds, Id masterContractId, Id existingOppId) {
        List<Contract> contractRecords = [SELECT Id FROM Contract WHERE Id IN :contractIds];

        Map<String, Object> renewalContext = new Map<String, Object>{
            'masterContractId' => masterContractId,
            'renewedContracts' => contractRecords
        };
        if (existingOppId == null) {
            renewalContext.put('returnOnlyQuoteId', true);
        }

        String response = SBQQ.ServiceRouter.load(
            'SBQQ.ContractManipulationAPI.ContractRenewer',
            masterContractId,
            JSON.serialize(renewalContext)
        );

        if (String.isBlank(response)) {
            throw new ContractRenewalService.ContractRenewalException(
                'ContractRenewer returned no response for contracts: ' + contractIds);
        }

        if (existingOppId == null) {
            Id quoteId = parseQuoteId(response);
            if (quoteId == null) {
                throw new ContractRenewalService.ContractRenewalException(
                    'ContractRenewer returned no usable quote ID. Response: ' + response);
            }
            List<SBQQ__Quote__c> quotes = [
                SELECT SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1
            ];
            if (quotes.isEmpty() || quotes[0].SBQQ__Opportunity2__c == null) {
                throw new ContractRenewalService.ContractRenewalException(
                    'Could not find Opportunity linked to renewal quote ' + quoteId);
            }
            return quotes[0].SBQQ__Opportunity2__c;
        }

        Map<String, Object> quoteModel = (Map<String, Object>) JSON.deserializeUntyped(response);
        Map<String, Object> record = (Map<String, Object>) quoteModel.get('record');
        if (record != null) {
            record.put('SBQQ__Opportunity2__c', existingOppId);
        }

        String savedJson = SBQQ.ServiceRouter.save(
            'SBQQ.QuoteAPI.QuoteSaver',
            JSON.serialize(quoteModel),
            null
        );

        if (String.isBlank(savedJson)) {
            throw new ContractRenewalService.ContractRenewalException(
                'QuoteSaver returned no response during remerge');
        }

        return existingOppId;
    }

    private static Id parseQuoteId(String raw) {
        Object data = JSON.deserializeUntyped(raw);
        if (data instanceof Map<String, Object>) {
            Object val = ((Map<String, Object>) data).get('Id');
            return val != null ? (Id) String.valueOf(val) : null;
        }
        if (data instanceof List<Object>) {
            List<Object> items = (List<Object>) data;
            if (!items.isEmpty()) {
                Object first = items[0];
                if (first instanceof Map<String, Object>) {
                    Object val = ((Map<String, Object>) first).get('Id');
                    return val != null ? (Id) String.valueOf(val) : null;
                }
                return first != null ? (Id) String.valueOf(first) : null;
            }
        }
        return data != null ? (Id) String.valueOf(data) : null;
    }
}
