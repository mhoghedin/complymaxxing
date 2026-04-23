public class CpqRenewalApi implements IRenewalApi {
    // Calls the CPQ managed package renewal API, then reads the generated opp ID
    // back from SBQQ__RenewalOpportunity__c which CPQ populates on the contract.
    public Id renewContracts(List<Id> contractIds) {
        SBQQ.ContractService.renewContracts(contractIds);
        return [
            SELECT SBQQ__RenewalOpportunity__c
            FROM Contract
            WHERE Id = :contractIds[0]
            LIMIT 1
        ].SBQQ__RenewalOpportunity__c;
    }
}
