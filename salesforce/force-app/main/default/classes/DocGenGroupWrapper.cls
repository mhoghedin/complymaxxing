public class DocGenGroupWrapper {
    @AuraEnabled public String groupLabel  { get; set; }
    @AuraEnabled public List<DocGenLineWrapper> lines { get; set; }
    @AuraEnabled public Decimal groupTotal { get; set; }

    public DocGenGroupWrapper(String groupLabel) {
        this.groupLabel = groupLabel;
        this.lines      = new List<DocGenLineWrapper>();
        this.groupTotal = 0;
    }
}
