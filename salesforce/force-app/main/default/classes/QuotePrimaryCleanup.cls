public class QuotePrimaryCleanup implements Schedulable {
    private Id targetOppId;
    private Id newQuoteId;

    public QuotePrimaryCleanup(Id targetOppId, Id newQuoteId) {
        this.targetOppId = targetOppId;
        this.newQuoteId = newQuoteId;
    }

    public void execute(SchedulableContext ctx) {
        try {
            // Uncheck ALL primaries on the opp — forces CPQ to re-sync products
            // when QuotePrimarySync re-promotes the new quote in the next transaction
            List<SObject> toDemote = Database.query(
                'SELECT Id FROM SBQQ__Quote__c ' +
                'WHERE SBQQ__Opportunity2__c = :targetOppId ' +
                'AND SBQQ__Primary__c = true'
            );
            for (SObject q : toDemote) {
                q.put('SBQQ__Primary__c', false);
            }
            if (!toDemote.isEmpty()) update toDemote;
        } catch (Exception ignored) {}

        try {
            DateTime runAt = DateTime.now().addMinutes(2);
            String cron = runAt.second() + ' ' + runAt.minute() + ' ' + runAt.hour()
                + ' ' + runAt.day() + ' ' + runAt.month() + ' ? ' + runAt.year();
            System.schedule('QuotePrimarySync_' + newQuoteId, cron,
                new QuotePrimarySync(targetOppId, newQuoteId));
        } catch (Exception ignored) {}
    }
}
