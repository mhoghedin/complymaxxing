public class QuotePrimarySync implements Schedulable {
    private Id newQuoteId;

    public QuotePrimarySync(Id newQuoteId) {
        this.newQuoteId = newQuoteId;
    }

    public void execute(SchedulableContext ctx) {
        try {
            List<SObject> quotes = Database.query(
                'SELECT Id FROM SBQQ__Quote__c WHERE Id = :newQuoteId LIMIT 1'
            );
            if (quotes.isEmpty()) return;
            quotes[0].put('SBQQ__Primary__c', true);
            update quotes[0];
        } catch (Exception ignored) {}
    }
}
