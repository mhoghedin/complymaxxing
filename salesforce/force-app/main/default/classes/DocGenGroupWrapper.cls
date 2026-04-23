public class DocGenGroupWrapper {
    @AuraEnabled public String groupLabel;
    @AuraEnabled public List<DocGenLineWrapper> lines;
    @AuraEnabled public Decimal groupTotal;

    public DocGenGroupWrapper(String groupLabel) {
        this.groupLabel = groupLabel;
        this.lines = new List<DocGenLineWrapper>();
        this.groupTotal = 0;
    }
}
