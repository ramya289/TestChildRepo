@namespaceAccessible
public with sharing class BillingHistoricalSyncBatch implements Database.Batchable<BreadwinnerBillingUtil.BillingAppConfig>, Database.AllowsCallouts, Database.Stateful, Schedulable {
    public List<BreadwinnerBillingUtil.BillingAppConfig> appConfigUpdateList = new List<BreadwinnerBillingUtil.BillingAppConfig>();
    public List<BreadwinnerBillingUtil.BillingAppConfig> appConfigList = new List<BreadwinnerBillingUtil.BillingAppConfig>();
    @namespaceAccessible
    public BreadwinnerUtil.AppConfig appConfig = new BreadwinnerUtil.AppConfig();
    @namespaceAccessible
    public String runningObjectName;
    Exception exceptionInExecute;
    @namespaceAccessible
    public Boolean runThisSyncOnly;
    public Integer requestRecordsCount;
    public String errors;

    //Constructor with BreadwinnerBillingUtil.BillingAppConfig input. This input will have updated BreadwinnerBillingUtil.BillingAppConfig data during runtime. It also can be used to run for specific BreadwinnerBillingUtil.BillingAppConfig.
    public BillingHistoricalSyncBatch(String objectName, List<BreadwinnerBillingUtil.BillingAppConfig> appconfigs) {
        if(BreadwinnerUtil.getBWSetting().Active__c){
            for(BreadwinnerBillingUtil.BillingAppConfig apC : appconfigs) {
                if(!apC.appconfig.needToReconnect && apc.appconfig.accessToken != NULL) {
                    appConfigList.add(apC);
                }
            }
        }
        runningObjectName = objectName;
        runThisSyncOnly = false;
    }
    
    //Constructor which runs for all connected ORGs.
    public BillingHistoricalSyncBatch(String objectName) {
        if(BreadwinnerUtil.getBWSetting().Active__c) {
            for(BWP_Processor_Config__c config : BreadwinnerBillingUtil.processorConfigList) {
                if(!config.Need_To_Reconnect__c && config.Access_Token__c != NULL) {
                    appConfigList.add(BreadwinnerBillingUtil.getProcessorConfigWrapper(config));
                }
            }
        }
        runningObjectName = objectName; 
        runThisSyncOnly = false;
    }

    //Constructor to call dynamically from the Payments package
    @namespaceAccessible
    public BillingHistoricalSyncBatch(){
        System.debug('Default Constructor');
        runThisSyncOnly = false;
    }
    //Start method
    public Iterable<BreadwinnerBillingUtil.BillingAppConfig> start(Database.Batchablecontext bc) {
        system.debug('start method');
        system.debug('appConfigList-----'+appConfigList);
        system.debug('runningObjectName-----'+runningObjectName);
        return appConfigList;
    }
    public void execute(Database.BatchableContext bc, List<BreadwinnerBillingUtil.BillingAppConfig> scope) {
        BreadwinnerBillingUtil.BillingAppConfig apc = scope[0];
        requestRecordsCount = 0;
        apc.appconfig.currentRunningClassContext = BreadwinnerUtil.CNTX_HIST_SYNC;

        if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT)){
            try {
                if(apc.appconfig.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                    if(apC.lastProductId != NULL){
                        fetchRequest.starting_after = apC.lastProductId;
                    }
                    //make max limit to 50 to reduce heap size and DML rows issues.
                    fetchRequest.stripe_limit = '50';
                    ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchProducts(apc, fetchRequest);
                    if(response.responseJSON != NULL){
                        processProductResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching products from '+apc.appconfig.paymentProcessorType+'.'+ex.getStackTraceString()+'See '+ex.getLineNumber()+'\n'+ex.getmessage());
                apc.requireNextProductSyncRun = False;
                exceptionInExecute = ex;
            }
        }
        else if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRICE)){
            try {
                if(apc.appconfig.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                    if(apC.lastPriceId != NULL){
                        fetchRequest.starting_after = apC.lastPriceId;
                    }
                    fetchRequest.stripe_limit = '50';
                    ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchPrices(apc, fetchRequest);
                    if(response.responseJSON != NULL){
                        processPriceResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching prices from '+apc.appconfig.paymentProcessorType+'.'+ex.getStackTraceString()+'See '+ex.getLineNumber()+'\n'+ex.getmessage());
                apc.requireNextPriceSyncRun = False;
                exceptionInExecute = ex;
            }
        }
        appConfigUpdateList.add(apc);
    }

    public void finish(Database.BatchableContext BC) {
        system.debug('finish: '+exceptionInExecute+' ');
        if(exceptionInExecute!=NULL) {
            APICallHandler.userInteractionLogPush(TRUE, 'Historical Sync', 'ERROR' , 'Historical Sync Exception in execute : ' + exceptionInExecute.getMessage() + ' Stack Trace : ' + exceptionInExecute.getStackTraceString());
        }
        if(BreadwinnerUtil.getBWSetting().Active__c && BreadwinnerUtil.isProcessorConnected()) {
            Map<Id,BWP_Processor_Config__c> appConfigMap = new Map<Id,BWP_Processor_Config__c>();
            
            //Collecting all app config records
            for(BWP_Processor_Config__c ac : BreadwinnerBillingUtil.processorConfigList) {
                appConfigMap.put(ac.Id, ac);
            }
            
            //Lists to separate failed records and app config records for next run.
            List<BreadwinnerBillingUtil.BillingAppConfig> appConfigNeedToRun = new List<BreadwinnerBillingUtil.BillingAppConfig>();
            List<BreadwinnerBillingUtil.BillingAppConfig> failedAppConfigs = new List<BreadwinnerBillingUtil.BillingAppConfig>();
            
            //List to save app config records to database.
            List<BWP_Processor_Config__c> appConfigNeedToUpdate = new List<BWP_Processor_Config__c>();
            for(BreadwinnerBillingUtil.BillingAppConfig appConfigWrapper : appConfigUpdateList) {
                Boolean recordExists = appConfigMap.containsKey(appConfigWrapper?.appconfig?.RecordId);
                BWP_Processor_Config__c appConfigCompleteRecord = recordExists ? appConfigMap.get(appConfigWrapper.appconfig.RecordId) : new BWP_Processor_Config__c();
                
                if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT)){
                    System.debug('Product Sync running at '+System.now()+' appConfigWrapper ::: '+appConfigWrapper);
                    if(appConfigWrapper.requireNextProductSyncRun && !appConfigWrapper.appconfig.needToReconnect) { //if more records
                        system.debug('appConfigWrapper---------'+appConfigWrapper.appconfig.accountname);
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextProductSyncRun && appConfigWrapper.appconfig.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        APICallHandler.userInteractionLogPush(TRUE, 'Historical Sync', 'FINISHED' , 'Object Name: Product, Syncing Processor: '+appConfigWrapper.appconfig.paymentProcessorType+' ('+appConfigWrapper.appconfig.accountName+'), CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Historical_Product_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.appconfig.needToReconnect;
                    appConfigNeedToUpdate.add(appConfigCompleteRecord);
                }
                if(runningObjectName.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRICE)){
                    System.debug('Price Sync running at '+System.now());
                    if(appConfigWrapper.requireNextPriceSyncRun && !appConfigWrapper.appconfig.needToReconnect) { //if more records
                        system.debug('appConfigWrapper---------'+appConfigWrapper.appconfig.accountname);
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextPriceSyncRun && appConfigWrapper.appconfig.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        APICallHandler.userInteractionLogPush(TRUE, 'Historical Sync', 'FINISHED' , 'Object Name: Price, Syncing Processor: '+appConfigWrapper.appconfig.paymentProcessorType+' ('+appConfigWrapper.appconfig.accountName+'), CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Historical_Price_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.appconfig.needToReconnect;
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
            } else if(appConfigNeedToRun.isEmpty() && appConfigNeedToUpdate.size()>0 && !runThisSyncOnly){
                System.debug('No more batches to run. So start Next batch.');
                system.debug('appConfigNeedToUpdate[0]----'+appConfigNeedToUpdate[0]);
                String getNextSyncObjectName = BreadwinnerBillingUtil.findNextSyncName(runningObjectName);
                if(String.isNotBlank(getNextSyncObjectName) && !BreadwinnerUtil.isBatchRunning(BreadwinnerUtil.CNTX_HIST_SYNC)) {
                    Database.executeBatch(new BillingHistoricalSyncBatch(getNextSyncObjectName), 1);
                }
            } 
        }
    }

    /* Schedulable - execute */
    @namespaceAccessible
    public void execute(SchedulableContext sc) {
        System.debug('appConfig ::: '+appConfig);
        if(BreadwinnerUtil.isAdministrator()) {
            if(BreadwinnerUtil.isBreadwinnerActive()) {
                CronTrigger ct = Schema.sObjectType.CronTrigger.isAccessible() ? [SELECT Id, CronExpression FROM CronTrigger WHERE Id =: sc.getTriggerId() LIMIT 1] : new CronTrigger();
                if(ct.CronExpression.containsIgnoreCase('BillingHistoricalSync')) {
                    //start the historical batch
                    runHistoricalSyncBatch(runningObjectName, runThisSyncOnly, appConfig);
                }
                //TODO need to handle weekly sync
            }
            else {
                APICallHandler.userInteractionLogPush(FALSE, 'Historical Scheduler', 'INFO', 'Trial or Subscription Expired');
            }
        }
        else {
            APICallHandler.userInteractionLogPush(FALSE, 'Historical Scheduler', 'INFO', 'Running user is not an Administrator');
        }
    }

     /* This method is used to run historical sync batch */
     public static void runHistoricalSyncBatch(String syncName, Boolean runThisSyncOnly, BreadwinnerUtil.AppConfig appConfig){
        String runningSyncName = String.isNotBlank(syncName) ? syncName : BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT;
        try{
            if(BreadwinnerUtil.isBreadwinnerAdministrator() && !BreadwinnerUtil.isBatchRunning(BreadwinnerBillingUtil.CNTX_BB_HIST_SYNC)) {
                BillingHistoricalSyncBatch historicalSync;
                if(appConfig.accountId != NULL){
                    List<BreadwinnerBillingUtil.BillingAppConfig> appCList = new List<BreadwinnerBillingUtil.BillingAppConfig>();
                    BreadwinnerBillingUtil.BillingAppConfig appC = new BreadwinnerBillingUtil.BillingAppConfig();
                    appC.appconfig = appConfig;
                    appCList.add(appC);
                    historicalSync = new BillingHistoricalSyncBatch(runningSyncName, appCList);
                }
                else historicalSync = new BillingHistoricalSyncBatch(runningSyncName);
                historicalSync.runThisSyncOnly = runThisSyncOnly;
                Database.executeBatch(historicalSync, 1); //At a time only one company should be run. Don't make it other than 1.
            }
        }
        catch(exception e){
            APICallHandler.userInteractionLogPush(FALSE, 'Historical Sync', 'ERROR' , 'Error occurred while restarting Historical '+runningSyncName+'Sync ' +e);
        }
    }

    public static void processProductResponse_Stripe(ProcessorUtil.ResponseObject response, BreadwinnerBillingUtil.BillingAppConfig apc, Integer requestRecordsCount){
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
    public static void processPriceResponse_Stripe(ProcessorUtil.ResponseObject response, BreadwinnerBillingUtil.BillingAppConfig apc, Integer requestRecordsCount){
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