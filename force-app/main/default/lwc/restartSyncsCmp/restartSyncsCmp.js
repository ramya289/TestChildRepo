import { LightningElement } from 'lwc';
import restartHistoricalSync from "@salesforce/apex/BreadwinnerBilling.restartHistoricalSync";

export default class RestartSyncsCmp extends LightningElement {
    clickedButtonLabel;

    handleClick(event) {
        this.clickedButtonLabel = event.target.label;
        restartHistoricalSync();
    }
}