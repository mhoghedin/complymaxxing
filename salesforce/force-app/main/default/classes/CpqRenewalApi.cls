public class CpqRenewalApi implements IRenewalApi {
    // Calls the CPQ managed package renewal API, then reads the generated opp ID back
    // from SBQQ__RenewalOpportunity__c. Queries the whole group — not just index 0 —
    // since CPQ is not guaranteed to populate the field on every contract immediately.
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
