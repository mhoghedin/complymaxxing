public class ContractRenewalQueueable implements Queueable, Database.AllowsCallouts {
    private List<List<Id>> groups;
    private List<Id> existingOppIds;
    private Integer index;

    @TestVisible static Boolean disableChaining = false;

    public ContractRenewalQueueable(List<List<Id>> groups, List<Id> existingOppIds, Integer index) {
        this.groups = groups;
        this.existingOppIds = existingOppIds;
        this.index = index;
    }

    public void execute(QueueableContext ctx) {
        List<Id> contractIds = groups[index];
        Id existingOppId = existingOppIds[index];

        try {
            ContractRenewalService.processGroup(contractIds, existingOppId);
        } catch (Exception e) {
            try {
                List<Contract> errored = new List<Contract>();
                for (Id cId : contractIds) {
                    errored.add(new Contract(
                        Id = cId,
                        Renewal_Error__c = e.getMessage().left(255)
                    ));
                }
                update errored;
            } catch (Exception ignored) {}
        }

        Integer nextIndex = index + 1;
        if (nextIndex < groups.size() && !disableChaining) {
            System.enqueueJob(new ContractRenewalQueueable(groups, existingOppIds, nextIndex));
        }
    }
}
