public interface IRenewalApi {
    Id renewContracts(List<Id> contractIds, Id masterContractId, Id existingOppId);
}
