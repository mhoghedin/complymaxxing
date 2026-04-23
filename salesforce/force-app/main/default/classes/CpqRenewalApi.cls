public class CpqRenewalApi implements IRenewalApi {
    // queries the whole group not just [0] — CPQ doesn't always populate every contract immediately
    public Id renewContracts(List<Id> contractIds) {
        SBQQ.ContractService.renewContracts(contractIds);
        List<Contract> renewed = [
            SELECT SBQQ__RenewalOpportunity__c
            FROM Contract
            WHERE Id IN :contractIds
            AND SBQQ__RenewalOpportunity__c != null
            LIMIT 1
        ];
        if (renewed.isEmpty()) {
            throw new ContractRenewalService.ContractRenewalException(
                'CPQ did not populate SBQQ__RenewalOpportunity__c on any contract in this group after renewContracts'
            );
        }
        return renewed[0].SBQQ__RenewalOpportunity__c;
    }
}
