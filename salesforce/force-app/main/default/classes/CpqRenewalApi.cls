public class CpqRenewalApi implements IRenewalApi {
    // SBQQ.ContractService.renewContracts is the real call — stubbed until confirmed
    // accessible in org (check profile/permission or CPQ version if this throws)
    public Id renewContracts(List<Id> contractIds) {
        throw new ContractRenewalService.ContractRenewalException(
            'CpqRenewalApi: SBQQ.ContractService not yet confirmed accessible in this org. ' +
            'Verify CPQ is installed and the running user has access to the SBQQ namespace.'
        );
    }
}
