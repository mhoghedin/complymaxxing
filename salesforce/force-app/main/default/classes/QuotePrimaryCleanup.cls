public class QuotePrimaryCleanup implements Schedulable {
    private Id targetOppId;
    private Id newQuoteId;

    public QuotePrimaryCleanup(Id targetOppId, Id newQuoteId) {
        this.targetOppId = targetOppId;
        this.newQuoteId = newQuoteId;
    }

    public void execute(SchedulableContext ctx) {
        try {
            Id nqId = newQuoteId;
            List<SObject> toDemote = Database.query(
                'SELECT Id FROM SBQQ__Quote__c ' +
                'WHERE SBQQ__Opportunity2__c = :targetOppId ' +
                'AND SBQQ__Primary__c = true ' +
                'AND Id != :nqId'
            );
            for (SObject q : toDemote) {
                q.put('SBQQ__Primary__c', false);
            }
            if (!toDemote.isEmpty()) update toDemote;

            update new Opportunity(Id = targetOppId, SBQQ__PrimaryQuote__c = newQuoteId);
        } catch (Exception ignored) {}
    }
}
