public class QuotePrimarySync implements Schedulable {
    private Id targetOppId;
    private Id newQuoteId;

    public QuotePrimarySync(Id targetOppId, Id newQuoteId) {
        this.targetOppId = targetOppId;
        this.newQuoteId = newQuoteId;
    }

    public void execute(SchedulableContext ctx) {
        try {
            SObject q = Database.query(
                'SELECT Id FROM SBQQ__Quote__c WHERE Id = :newQuoteId LIMIT 1'
            )[0];
            q.put('SBQQ__Primary__c', true);
            update q;
        } catch (Exception ignored) {}
    }
}
