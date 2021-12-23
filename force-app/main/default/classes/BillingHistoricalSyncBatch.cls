public with sharing class BillingHistoricalSyncBatch implements Database.Batchable<BreadwinnerUtil.AppConfig>, Database.AllowsCallouts, Database.Stateful {
    public List<BreadwinnerUtil.AppConfig> appConfigUpdateList = new List<BreadwinnerUtil.AppConfig>();
    public List<BreadwinnerUtil.AppConfig> appConfigList = new List<BreadwinnerUtil.AppConfig>();
    public String runningObjectName;
    Exception exceptionInExecute;
    public Boolean runThisSyncOnly;
    public Integer requestRecordsCount;
    public String errors;

    //Constructor with BreadwinnerUtil.AppConfig input. This input will have updated BreadwinnerUtil.AppConfig data during runtime. It also can be used to run for specific BreadwinnerUtil.AppConfig.
    public BillingHistoricalSyncBatch(String objectName, List<BreadwinnerUtil.AppConfig> appconfigs) {
        System.debug('Testing Method1');
        if(BreadwinnerUtil.getBWSetting().Active__c){
            for(BreadwinnerUtil.AppConfig apC : appconfigs) {
                if(!apC.needToReconnect && apc.accessToken != NULL) {
                    appConfigList.add(apC);
                }
            }
        }
        runningObjectName = String.isNotBlank(objectName) ? objectName : '';
        runThisSyncOnly = false;
    }
    
    //Default Constructor which runs for all connected ORGs.
    public BillingHistoricalSyncBatch(String objectName) {
        System.debug('Testing Method2');
        if(BreadwinnerUtil.getBWSetting().Active__c) {
            for(BWP_Processor_Config__c config : BreadwinnerUtil.processorConfigList) {
                if(!config.Need_To_Reconnect__c && config.Access_Token__c != NULL) {
                    appConfigList.add(BreadwinnerUtil.getProcessorConfigWrapper(config));
                }
            }
        }
        runningObjectName = String.isNotBlank(objectName) ? objectName : ''; 
        runThisSyncOnly = false;
    }
    public BillingHistoricalSyncBatch(){
        runThisSyncOnly = false;
    }
    //Start method
    public Iterable<BreadwinnerUtil.AppConfig> start(Database.Batchablecontext bc) {
        system.debug('start method');
        system.debug('appConfigList-----'+appConfigList);
        system.debug('runningObjectName-----'+runningObjectName);
        return appConfigList;
    }
    public void execute(Database.BatchableContext bc, List<BreadwinnerUtil.AppConfig> scope) {
        BreadwinnerUtil.AppConfig apc = scope[0];
        requestRecordsCount = 0;
        apc.currentRunningClassContext = BreadwinnerUtil.CNTX_HIST_SYNC;

        if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT)){
            try {
                Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                if(apc.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    if(apC.lastProductId != NULL){
                        fetchRequest.starting_after = apC.lastProductId;
                    }
                    fetchRequest.stripe_limit = '50';
                }
                ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchProducts(apc, fetchRequest);
                if(response.responseJSON != NULL){
                    if(apc.PaymentProcessorType == ProcessorUtil.PAT_STRIPE){
                        processProductResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching customers from '+apc.paymentProcessorType+'.'+ex.getStackTraceString()+'See '+ex.getLineNumber()+'\n'+ex.getmessage());
                apc.requireNextProductSyncRun = False;
                exceptionInExecute = ex;
            }
        }
        else if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRICE)){
            try {
                Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                if(apc.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    if(apC.lastPriceId != NULL){
                        fetchRequest.starting_after = apC.lastPriceId;
                    }
                    fetchRequest.stripe_limit = '50';
                }
                ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchPrices(apc, fetchRequest);
                if(response.responseJSON != NULL){
                    if(apc.PaymentProcessorType == ProcessorUtil.PAT_STRIPE){
                        processPriceResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching customers from '+apc.paymentProcessorType+'.'+ex.getStackTraceString()+'See '+ex.getLineNumber()+'\n'+ex.getmessage());
                apc.requireNextPriceSyncRun = False;
                exceptionInExecute = ex;
            }
        }
        appConfigUpdateList.add(apc);
    }

    public void finish(Database.BatchableContext BC) {
        system.debug('finish: '+exceptionInExecute);
        if(exceptionInExecute!=NULL) {
            APICallHandler.userInteractionLogPush(TRUE, 'Historical Sync', 'ERROR' , 'Historical Sync Exception in execute : ' + exceptionInExecute.getMessage() + ' Stack Trace : ' + exceptionInExecute.getStackTraceString());
        }
        postSyncUpdates(appConfigUpdateList, runningObjectName, requestRecordsCount, runThisSyncOnly, false);
    }

    // Added this method for reusability, this will update Processor Config after Customer/Payment Sync is completed
    public static void postSyncUpdates(List<BreadwinnerUtil.AppConfig> appConfigUpdateList, String runningObjectName, Integer requestRecordsCount, Boolean runThisSyncOnly, Boolean isSyncCompleted){
        if(BreadwinnerUtil.getBWSetting().Active__c && BreadwinnerUtil.isProcessorConnected()) {
            Map<Id,BWP_Processor_Config__c> appConfigMap = new Map<Id,BWP_Processor_Config__c>();
            
            //Collecting all app config records
            for(BWP_Processor_Config__c ac : BreadwinnerUtil.processorConfigList) {
                appConfigMap.put(ac.Id, ac);
            }
            
            //Lists to separate failed records and app config records for next run.
            List<BreadwinnerUtil.AppConfig> appConfigNeedToRun = new List<BreadwinnerUtil.AppConfig>();
            List<BreadwinnerUtil.AppConfig> failedAppConfigs = new List<BreadwinnerUtil.AppConfig>();
            
            //List to save app config records to database.
            List<BWP_Processor_Config__c> appConfigNeedToUpdate = new List<BWP_Processor_Config__c>();
            for(BreadwinnerUtil.AppConfig appConfigWrapper : appConfigUpdateList) {
                Boolean recordExists = ((String.isNotBlank(appConfigWrapper.RecordId) && (appConfigWrapper.RecordId != NULL)) ? (appConfigMap.containsKey(appConfigWrapper.RecordId) ? true : false) : false);
                BWP_Processor_Config__c appConfigCompleteRecord = recordExists ? appConfigMap.get(appConfigWrapper.RecordId) : new BWP_Processor_Config__c();
                
                if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT)){
                    System.debug('Product Sync running at '+System.now());
                    if(appConfigWrapper.requireNextProductSyncRun && !appConfigWrapper.needToReconnect) { //if more records
                        appConfigWrapper.isHistoricalProductSyncDone = false;
                        system.debug('appConfigWrapper---------'+appConfigWrapper.accountname);
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextProductSyncRun && appConfigWrapper.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        appConfigWrapper.isHistoricalProductSyncDone = true;
                        APICallHandler.userInteractionLogPush(TRUE, 'Historical Sync', 'FINISHED' , 'Object Name: Product, Syncing Processor: '+appConfigWrapper.paymentProcessorType+' ('+appConfigWrapper.accountName+'), CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Historical_Product_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.needToReconnect;
                    appConfigNeedToUpdate.add(appConfigCompleteRecord);
                }
                if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRICE)){
                    System.debug('Price Sync running at '+System.now());
                    if(appConfigWrapper.requireNextPriceSyncRun && !appConfigWrapper.needToReconnect) { //if more records
                        system.debug('appConfigWrapper---------'+appConfigWrapper.accountname);
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextPriceSyncRun && appConfigWrapper.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        APICallHandler.userInteractionLogPush(TRUE, 'Historical Sync', 'FINISHED' , 'Object Name: Product, Syncing Processor: '+appConfigWrapper.paymentProcessorType+' ('+appConfigWrapper.accountName+'), CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Historical_Price_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.needToReconnect;
                    appConfigNeedToUpdate.add(appConfigCompleteRecord);
                }
            }
            BreadwinnerUtil.isBreadwinnerTransaction = true;
            SecurityUtil.databaseUpsert(appConfigNeedToUpdate);
            
            if(!appConfigNeedToRun.isEmpty()) {
                system.debug('appConfigNeedToRun------------'+appConfigNeedToRun);
                if(!Test.isRunningTest()){
                    BillingHistoricalSyncBatch historicalSync = new BillingHistoricalSyncBatch(runningObjectName, appConfigNeedToRun);
                    historicalSync.runThisSyncOnly = runThisSyncOnly ? true : false;
                    Database.executeBatch(historicalSync, 1);
                }
            } else if(appConfigNeedToRun.isEmpty() && appConfigNeedToUpdate.size()>0 && !runThisSyncOnly){ //No more batches to run. So start Next batch.
                System.debug('No more batches to run. So start Next batch.');
                system.debug('appConfigNeedToUpdate[0]----'+appConfigNeedToUpdate[0]);
                String getNextSyncObjectName = BreadwinnerBillingUtil.findNextSyncName(runningObjectName);
                if(String.isNotBlank(getNextSyncObjectName) && !BreadwinnerUtil.isBatchRunning(BreadwinnerUtil.CNTX_HIST_SYNC)) {
                    Database.executeBatch(new BillingHistoricalSyncBatch(getNextSyncObjectName), 1);
                }
            }
            
        }
    }

    public static void processProductResponse_Stripe(ProcessorUtil.ResponseObject response, BreadwinnerUtil.AppConfig apc, Integer requestRecordsCount){
        Map<String, Product.StripeProduct> stripeProductMapById = new Map<String, Product.StripeProduct>();
        Map<String, Object> processorTypeToRecordsMap = new Map<String, Object>();
        String responseJSON = (String) response.responseJSON;
        JSONParser parser = JSON.createParser(responseJSON);
        Processor_Billing_Stripe.FetchResponse responseData = (Processor_Billing_Stripe.FetchResponse) parser.readValueAs(Processor_Billing_Stripe.FetchResponse.class);
        stripeProductMapById = responseData.productMapById;
        if(responseData.requireNextRun){
            apc.lastProductId = responseData.last_record_id;
            apc.requireNextProductSyncRun = TRUE;
        }
        else{
            apc.lastProductId = '';
            apc.requireNextProductSyncRun = FALSE;
        }
        if(stripeProductMapById != NULL){
            processorTypeToRecordsMap.put(ProcessorUtil.PAT_STRIPE, stripeProductMapById);
            System.debug('stripeProductMapById ::: '+stripeProductMapById);
            requestRecordsCount = stripeProductMapById.size() > 0 ? stripeProductMapById.size() : 0;
            if(requestRecordsCount > 0)
                Processor_Billing_Stripe.syncProducts(stripeProductMapById, apC);
        }
    }
    public static void processPriceResponse_Stripe(ProcessorUtil.ResponseObject response, BreadwinnerUtil.AppConfig apc, Integer requestRecordsCount){
        Map<String, Product.StripePrice> stripePriceMapById = new Map<String, Product.StripePrice>();
        Map<String, Object> processorTypeToRecordsMap = new Map<String, Object>();
        String responseJSON = (String) response.responseJSON;
        JSONParser parser = JSON.createParser(responseJSON);
        Processor_Billing_Stripe.FetchResponse responseData = (Processor_Billing_Stripe.FetchResponse) parser.readValueAs(Processor_Billing_Stripe.FetchResponse.class);
        stripePriceMapById = responseData.priceMapById;
        if(responseData.requireNextRun){
            apc.lastPriceId = responseData.last_record_id;
            apc.requireNextPriceSyncRun = TRUE;
        }
        else{
            apc.lastPriceId = '';
            apc.requireNextPriceSyncRun = FALSE;
        }
        if(stripePriceMapById != NULL){
            processorTypeToRecordsMap.put(ProcessorUtil.PAT_STRIPE, stripePriceMapById);
            System.debug('stripePriceMapById ::: '+stripePriceMapById);
            requestRecordsCount = stripePriceMapById.size() > 0 ? stripePriceMapById.size() : 0;
            if(requestRecordsCount > 0)
                Processor_Billing_Stripe.syncPrices(stripePriceMapById, apC);
        }
    }
}