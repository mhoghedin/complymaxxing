import { LightningElement, track } from 'lwc';
import getAvailableTemplates  from '@salesforce/apex/DocGenController.getAvailableTemplates';
import getGroupByOptions       from '@salesforce/apex/DocGenController.getGroupByOptions';
import getContracts            from '@salesforce/apex/DocGenController.getContracts';
import getSubscriptionPreview  from '@salesforce/apex/DocGenController.getSubscriptionPreview';
import generateDocument        from '@salesforce/apex/DocGenController.generateDocument';

const fmt = (val) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val ?? 0);

export default class DocGenWizard extends LightningElement {

    @track currentStep         = '1';
    @track contracts           = [];
    @track selectedContractIds = [];
    @track groupBy             = '';   // field API name, set once options load
    @track groupByLabel        = '';
    @track groupOptions        = [];
    @track previewGroups       = [];
    @track templateOptions     = [];
    @track selectedTemplateId  = '';
    @track downloadUrl         = '';
    @track isLoading           = false;
    @track errorMessage        = '';

    /* ─── Lifecycle ─────────────────────────────────────────────── */

    connectedCallback() {
        this.loadContracts('');
        this.loadTemplates();
        this.loadGroupOptions();
    }

    /* ─── Data loading ──────────────────────────────────────────── */

    loadContracts(searchTerm) {
        getContracts({ searchTerm })
            .then(result => { this.contracts = result; })
            .catch(err   => { this.errorMessage = this.extractError(err); });
    }

    loadTemplates() {
        getAvailableTemplates()
            .then(result => {
                this.templateOptions = result.map(t => ({ label: t.Name, value: t.Id }));
            })
            .catch(err => { this.errorMessage = this.extractError(err); });
    }

    loadGroupOptions() {
        getGroupByOptions()
            .then(result => {
                this.groupOptions = result;
                // pick the first CMT option as the default
                if (result.length > 0 && !this.groupBy) {
                    this.groupBy      = result[0].value;
                    this.groupByLabel = result[0].label;
                }
            })
            .catch(err => { this.errorMessage = this.extractError(err); });
    }

    /* ─── Step 1 ────────────────────────────────────────────────── */

    handleSearch(event) {
        this.loadContracts(event.target.value);
    }

    handleContractToggle(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedContractIds = this.selectedContractIds.includes(id)
            ? this.selectedContractIds.filter(x => x !== id)
            : [...this.selectedContractIds, id];
    }

    /* ─── Step 2 ────────────────────────────────────────────────── */

    handleGroupByChange(event) {
        this.groupBy = event.detail.value;
        const match = this.groupOptions.find(o => o.value === this.groupBy);
        this.groupByLabel = match ? match.label : '';
    }

    /* ─── Step 3 — preview ──────────────────────────────────────── */

    loadPreview() {
        this.isLoading    = true;
        this.currentStep  = '3';
        this.errorMessage = '';

        getSubscriptionPreview({
            contractIds:  this.selectedContractIds,
            groupByField: this.groupBy
        })
        .then(result => {
            // product names aren't unique across contracts — key by index instead
            this.previewGroups = result.map((grp, gi) => ({
                ...grp,
                groupTotalFormatted: fmt(grp.groupTotal),
                lines: grp.lines.map((ln, li) => ({
                    ...ln,
                    lineKey: `g${gi}-l${li}`,
                    netPriceFormatted:  fmt(ln.netPrice),
                    listPriceFormatted: fmt(ln.listPrice)
                }))
            }));
            this.isLoading = false;
        })
        .catch(err => {
            this.errorMessage = this.extractError(err);
            this.isLoading    = false;
            this.currentStep  = '2';
        });
    }

    /* ─── Step 4 ────────────────────────────────────────────────── */

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    generateDocument() {
        this.isLoading    = true;
        this.errorMessage = '';

        generateDocument({
            contractIds:  this.selectedContractIds,
            groupByField: this.groupBy,
            templateId:   this.selectedTemplateId
        })
        .then(url => {
            this.downloadUrl = url;
            this.isLoading   = false;
        })
        .catch(err => {
            this.errorMessage = this.extractError(err);
            this.isLoading    = false;
        });
    }

    /* ─── Navigation ────────────────────────────────────────────── */

    goToStep1() { this.currentStep = '1'; }
    goToStep2() { this.currentStep = '2'; }
    goToStep3() { this.currentStep = '3'; }
    goToStep4() { this.currentStep = '4'; }

    clearError() { this.errorMessage = ''; }

    reset() {
        this.currentStep         = '1';
        this.selectedContractIds = [];
        this.previewGroups       = [];
        this.selectedTemplateId  = '';
        this.downloadUrl         = '';
        this.errorMessage        = '';
        this.loadContracts('');
    }

    /* ─── Getters ───────────────────────────────────────────────── */

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    get noContractsSelected()      { return this.selectedContractIds.length === 0; }
    get noTemplateSelected()       { return !this.selectedTemplateId; }
    get noGroupBySelected()        { return !this.groupBy; }
    get noContracts()              { return this.contracts.length === 0; }
    get selectedCount()            { return this.selectedContractIds.length; }
    get noGroupOptions()           { return this.groupOptions.length === 0; }
    get cannotProceedToGenerate()  { return this.isLoading || this.previewGroups.length === 0; }

    get grandTotalFormatted() {
        const total = this.previewGroups.reduce((sum, g) => sum + (g.groupTotal ?? 0), 0);
        return fmt(total);
    }

    get contractsWithSelection() {
        return this.contracts.map(c => ({
            ...c,
            isSelected: this.selectedContractIds.includes(c.Id),
            rowClass: 'docgen-contract-row' +
                      (this.selectedContractIds.includes(c.Id) ? ' selected' : '')
        }));
    }

    /* ─── Helpers ───────────────────────────────────────────────── */

    extractError(err) {
        return err?.body?.message ?? err?.message ?? 'An unexpected error occurred.';
    }
}
