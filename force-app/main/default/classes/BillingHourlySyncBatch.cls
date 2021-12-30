public with sharing class BillingHourlySyncBatch implements Database.Batchable<BreadwinnerBillingUtil.BillingAppConfig>, Database.AllowsCallouts, Database.Stateful, Schedulable {
    public List<BreadwinnerBillingUtil.BillingAppConfig> appConfigUpdateList = new List<BreadwinnerBillingUtil.BillingAppConfig>();
    public List<BreadwinnerBillingUtil.BillingAppConfig> appConfigList = new List<BreadwinnerBillingUtil.BillingAppConfig>();
    public String runningObject;
    Exception exceptionInExecute;
    public Integer requestRecordsCount;
    public String errors;

    public BillingHourlySyncBatch(String objectName, List<BreadwinnerBillingUtil.BillingAppConfig> appconfigs) {
        if(BreadwinnerUtil.getBWSetting().Active__c) {
            for(BreadwinnerBillingUtil.BillingAppConfig apC : appconfigs) {
                if(!apC.appconfig.needToReconnect && apc.appconfig.accessToken != NULL) {
                    appConfigList.add(apC);
                }
            }
        }
        runningObject = String.isNotBlank(objectName) ? objectName : '';
        system.debug('appConfigList----'+appConfigList);
    }
    public BillingHourlySyncBatch(String objectName) {
        if(BreadwinnerUtil.getBWSetting().Active__c) {
            for(BWP_Processor_Config__c config : BreadwinnerBillingUtil.processorConfigList) {
                if(!config.Need_To_Reconnect__c && config.Access_Token__c != NULL) {
                    appConfigList.add(BreadwinnerBillingUtil.getProcessorConfigWrapper(config));
                }
            }
        } 
        runningObject = String.isNotBlank(objectName) ? objectName : '';
        system.debug('appConfigList----'+appConfigList);
    }

    // This constructor can be used to call dynamically from the Payments package
    public BillingHourlySyncBatch(){
        scheduleBreadwinnerHourlySync(1, true);
    }

    //Start method
    public Iterable<BreadwinnerBillingUtil.BillingAppConfig> start(Database.Batchablecontext bc) {
        system.debug('start method');
        system.debug('appConfigs------'+appConfigList);
        return appConfigList;
    }

    public void execute(Database.BatchableContext bc, List<BreadwinnerBillingUtil.BillingAppConfig> scope) {
        system.debug('execute method-----------------');
        BreadwinnerBillingUtil.BillingAppConfig apc = scope[0];
        requestRecordsCount = 0;
        apc.appconfig.currentRunningClassContext = BreadwinnerUtil.CNTX_HOUR_SYNC;     
        
        if(runningObject == BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT) {
            try {
                Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                if(apc.appconfig.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    DateTime lastHourDateTime = apc.hourlyProductSyncLastRun != null ? apc.hourlyProductSyncLastRun.addMinutes(-20) : System.now().addMinutes(-200);
                    fetchRequest.createdGreaterThanOrEqual = String.valueOf(lastHourDateTime);
                    if(apC.lastProductId != NULL){
                        fetchRequest.starting_after = apC.lastProductId;
                    }
                    fetchRequest.stripe_limit = '50';
                }
                ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchProducts(apc, fetchRequest);
                if(response.responseJSON != NULL){
                    if(apc.appconfig.PaymentProcessorType == ProcessorUtil.PAT_STRIPE){
                        BillingHistoricalSyncBatch.processProductResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching products from Stripe.'+ex.getStackTraceString()+'\n'+ex.getMessage());
                apc.requireNextProductSyncRun = false;
                exceptionInExecute = ex;
            }
        } else if(runningObject == BreadwinnerBillingUtil.OBJ_SYNC_PRICE) {
            try {
                Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                if(apc.appconfig.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    DateTime lastHourDateTime = apc.hourlyPriceSyncLastRun != null ? apc.hourlyPriceSyncLastRun.addMinutes(-20) : System.now().addMinutes(-200);
                    fetchRequest.createdGreaterThanOrEqual = String.valueOf(lastHourDateTime);
                    if(apC.lastPriceId != NULL){
                        fetchRequest.starting_after = apC.lastPriceId;
                    }
                    fetchRequest.stripe_limit = '50';
                }
                ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchPrices(apc, fetchRequest);
                if(response.responseJSON != NULL){
                    if(apc.appconfig.PaymentProcessorType == ProcessorUtil.PAT_STRIPE){
                        BillingHistoricalSyncBatch.processPriceResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching prices from Stripe.'+ex.getStackTraceString()+'\n'+ex.getMessage());
                apc.requireNextPriceSyncRun = false;
                exceptionInExecute = ex;
            }
        }
        appConfigUpdateList.add(apc);
    }
    public void finish(Database.BatchableContext BC) {
        system.debug('finish method--------------');
        if(exceptionInExecute!=NULL){
            APICallHandler.userInteractionLogPush(TRUE, 'Hourly Sync', 'ERROR' , 'Hourly Sync Exception in execute : ' + exceptionInExecute.getMessage() + ' Stack Trace : ' + exceptionInExecute.getStackTraceString());
        }
        if(BreadwinnerUtil.getBWSetting().Active__c && BreadwinnerUtil.isProcessorConnected()) {
            Map<ID,BWP_Processor_Config__c> appConfigMap = new Map<ID,BWP_Processor_Config__c>();
            
            //Collecting all app config records
            for(BWP_Processor_Config__c ac : BreadwinnerBillingUtil.processorConfigList) {
                appConfigMap.put(ac.Id, ac);
            }
            
            //Lists to seperate failed records and app config records for next run.
            List<BreadwinnerBillingUtil.BillingAppConfig> appConfigNeedToRun = new List<BreadwinnerBillingUtil.BillingAppConfig>();
            List<BreadwinnerBillingUtil.BillingAppConfig> failedAppConfigs = new List<BreadwinnerBillingUtil.BillingAppConfig>();
            
            List<BWP_Processor_Config__c> appConfigNeedToUpdate = new List<BWP_Processor_Config__c>(); //List to save app config records to database.
            
            for(BreadwinnerBillingUtil.BillingAppConfig appConfigWrapper : appConfigUpdateList) {
                Boolean recordExists = 
                    appConfigWrapper.appconfig.RecordId != NULL &&
                    appConfigMap.containsKey(appConfigWrapper.appconfig.RecordId);
                BWP_Processor_Config__c appConfigCompleteRecord = recordExists ? appConfigMap.get(appConfigWrapper.appconfig.RecordId) : new BWP_Processor_Config__c();
                
                if(runningObject.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT)){
                    System.debug('Product Sync running at '+System.now());
                    if(appConfigWrapper.requireNextProductSyncRun && !appConfigWrapper.appconfig.needToReconnect) { //if more records
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextProductSyncRun && appConfigWrapper.appconfig.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        APICallHandler.userInteractionLogPush(TRUE, 'Hourly Sync', 'FINISHED' , 'Object Name: Product, Syncing Processor: '+appConfigWrapper.appconfig.paymentProcessorType+' ('+appConfigWrapper.appconfig.accountName+'), Requested LastSyncDateTime: '+appConfigCompleteRecord.Hourly_Product_Sync_Last_Run__c+', CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Hourly_Product_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.appconfig.needToReconnect;
                    appConfigNeedToUpdate.add(appConfigCompleteRecord);
                    
                }else if(runningObject.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRICE)){
                    
                    if(appConfigWrapper.requireNextPriceSyncRun && !appConfigWrapper.appconfig.needToReconnect) { //if more records
                        system.debug('need price sync run');
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextPriceSyncRun && appConfigWrapper.appconfig.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        APICallHandler.userInteractionLogPush(TRUE, 'Hourly Sync', 'FINISHED' , 'Object Name: Price, Syncing Processor: '+appConfigWrapper.appconfig.paymentProcessorType+' ('+appConfigWrapper.appconfig.accountName+'), Requested LastSyncDateTime: '+appConfigCompleteRecord.Hourly_Price_Sync_Last_Run__c+', CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Hourly_Price_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.appconfig.needToReconnect;
                    appConfigNeedToUpdate.add(appConfigCompleteRecord);
                }
            }
            BreadwinnerUtil.isBreadwinnerTransaction = true;
            SecurityUtil.databaseUpsert(appConfigNeedToUpdate);
            
            if(!appConfigNeedToRun.isEmpty()) {
                system.debug('execute---another');
                if(!Test.isRunningTest()){
                    BillingHourlySyncBatch hourlySync = new BillingHourlySyncBatch(runningObject, appConfigNeedToRun);
                    Database.executeBatch(hourlySync, 1);
                }
            } else if(appConfigNeedToRun.isEmpty() && appConfigNeedToUpdate.size()>0) {
                System.debug('No more batches to run. So start Next batch.');
                if(!BreadwinnerUtil.isBatchRunning(BreadwinnerUtil.CNTX_HOUR_SYNC)) {
                    String getNextSyncObjectName = BreadwinnerBillingUtil.findNextSyncName(runningObject);
                    if(String.isNotBlank(getNextSyncObjectName)) {
                        Database.executeBatch(new BillingHourlySyncBatch(getNextSyncObjectName), 1);
                    } else {
                        scheduleBreadwinnerHourlySync(15, true);
                    }
                }
            }
        }
    }
    /* Schedulable - execute */
    public void execute(SchedulableContext sc) {
        if(BreadwinnerUtil.isAdministrator()) {
            if(BreadwinnerUtil.isBreadwinnerActive()) {
                runHourlySyncBatch();
            }
            else {
                APICallHandler.userInteractionLogPush(FALSE, 'Hourly Scheduler', 'INFO', 'Trial or Subscription Expired');
            }
        }
        else {
            APICallHandler.userInteractionLogPush(FALSE, 'Hourly Scheduler', 'INFO', 'Running user is not an Administrator');
        }
    }
    /* This method is used to run hourly sync batch */
    public static void runHourlySyncBatch(){
        try{
            if(BreadwinnerUtil.isBreadwinnerAdministrator() && !BreadwinnerUtil.isBatchRunning(BreadwinnerUtil.CNTX_HOUR_SYNC)) {
                BillingHourlySyncBatch hourlySync = new BillingHourlySyncBatch(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT);
                Database.executeBatch(hourlySync, 1); //At a time only one company should be run. Don't make it other than 1.
            }
        }
        catch(Exception e){
            APICallHandler.userInteractionLogPush(false, 'Hourly Sync', 'ERROR' , 'Error occurred while restarting Hourly Sync ' +e);
        }
    }
    public static void scheduleBreadwinnerHourlySync(Integer minutes, Boolean abortExistedJobs) {
        if(BreadwinnerUtil.isBreadwinnerAdministrator()) {
            try {
                List<CronTrigger> existedScheduledJobs = BreadwinnerUtil.getCronTrigger('BreadwinnerBillingHourlySync');

                if(existedScheduledJobs.size()>0 && abortExistedJobs) {
                    for(CronTrigger ct : existedScheduledJobs) {
                        System.abortJob(ct.id); //-- Abort the pending jobs
                    }
                }
                if(existedScheduledJobs.size() == 0 || abortExistedJobs) {
                    DateTime nextScheduleTime = System.now().addMinutes(minutes);
                    String CronExpression = '0 ' + nextScheduleTime.minute() + ' ' + nextScheduleTime.hour() + ' ' + nextScheduleTime.day() + ' ' + nextScheduleTime.month() + ' ? ' + nextScheduleTime.year() + ' BillingBreadwinnerSync';
                    BillingHourlySyncBatch hourlySync = new BillingHourlySyncBatch(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT);
                    System.schedule('BreadwinnerBillingHourlySync' + System.now(), CronExpression, hourlySync);
                }
            }
            catch(Exception e) {
                System.debug('Exception occured while scheduling Breadwinner Hourly Sync: ' + e.getMessage());
            }
        }
    }
}