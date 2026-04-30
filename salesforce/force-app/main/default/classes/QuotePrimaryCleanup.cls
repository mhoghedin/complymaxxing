public class QuotePrimaryCleanup implements Schedulable {
    private static final Integer SYNC_DELAY_MINUTES = 2;

    private Id targetOppId;
    private Id newQuoteId;

    public QuotePrimaryCleanup(Id targetOppId, Id newQuoteId) {
        this.targetOppId = targetOppId;
        this.newQuoteId = newQuoteId;
    }

    public void execute(SchedulableContext ctx) {
        try {
            // Uncheck all primaries so CPQ re-syncs products when QuotePrimarySync promotes the new one
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
            System.schedule('QuotePrimarySync_' + newQuoteId, buildCron(SYNC_DELAY_MINUTES),
                new QuotePrimarySync(newQuoteId));
        } catch (Exception ignored) {}
    }

    private static String buildCron(Integer delayMinutes) {
        DateTime runAt = DateTime.now().addMinutes(delayMinutes);
        return runAt.second() + ' ' + runAt.minute() + ' ' + runAt.hour()
            + ' ' + runAt.day() + ' ' + runAt.month() + ' ? ' + runAt.year();
    }
}
