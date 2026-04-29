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
        Id finalOppId = renewApi.renewContracts(contractIds, masterContractId, existingRenewalOppId);

        if (finalOppId != null) {
            List<Contract> toUpdate = new List<Contract>();
            for (Id cId : contractIds) {
                toUpdate.add(new Contract(Id = cId, SBQQ__RenewalOpportunity__c = finalOppId));
            }
            update toUpdate;
        }
    }
}
