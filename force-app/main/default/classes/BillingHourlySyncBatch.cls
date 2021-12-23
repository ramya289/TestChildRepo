public with sharing class BillingHourlySyncBatch implements Database.Batchable<BreadwinnerUtil.AppConfig>, Database.AllowsCallouts, Database.Stateful, Schedulable {
    public List<BreadwinnerUtil.AppConfig> appConfigUpdateList = new List<BreadwinnerUtil.AppConfig>();
    public List<BreadwinnerUtil.AppConfig> appConfigList = new List<BreadwinnerUtil.AppConfig>();
    public String runningObject;
    Exception exceptionInExecute;
    public Integer requestRecordsCount;
    public String errors;

    public BillingHourlySyncBatch(String objectName, List<BreadwinnerUtil.AppConfig> appconfigs) {
        if(BreadwinnerUtil.getBWSetting().Active__c) {
            for(BreadwinnerUtil.AppConfig apC : appconfigs) {
                if(!apC.needToReconnect && apc.accessToken != NULL) {
                    appConfigList.add(apC);
                }
            }
        }
        runningObject = String.isNotBlank(objectName) ? objectName : '';
        system.debug('appConfigList----'+appConfigList);
    }
    public BillingHourlySyncBatch(String objectName) {
        if(BreadwinnerUtil.getBWSetting().Active__c) {
            for(BWP_Processor_Config__c config : BreadwinnerUtil.processorConfigList) {
                if(!config.Need_To_Reconnect__c && config.Access_Token__c != NULL) {
                    appConfigList.add(BreadwinnerUtil.getProcessorConfigWrapper(config));
                }
            }
        } 
        runningObject = String.isNotBlank(objectName) ? objectName : '';
        system.debug('appConfigList----'+appConfigList);
    }

    public BillingHourlySyncBatch(){
        scheduleBreadwinnerHourlySync(1, true);
    }

    //Start method
    public Iterable<BreadwinnerUtil.AppConfig> start(Database.Batchablecontext bc) {
        system.debug('start method');
        system.debug('appConfigs------'+appConfigList);
        return appConfigList;
    }

    public void execute(Database.BatchableContext bc, List<BreadwinnerUtil.AppConfig> scope) {
        system.debug('execute method-----------------');
        BreadwinnerUtil.AppConfig apc = scope[0];
        requestRecordsCount = 0;
        apc.currentRunningClassContext = BreadwinnerUtil.CNTX_HOUR_SYNC;     
        
        if(runningObject == BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT) {
            try {
                Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                if(apc.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    DateTime lastHourDateTime = apc.hourlyProductSyncLastRun != null ? apc.hourlyProductSyncLastRun.addMinutes(-20) : System.now().addMinutes(-200);
                    fetchRequest.createdGreaterThanOrEqual = String.valueOf(lastHourDateTime);
                    if(apC.lastProductId != NULL){
                        fetchRequest.starting_after = apC.lastProductId;
                    }
                    fetchRequest.stripe_limit = '50';
                }
                ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchProducts(apc, fetchRequest);
                if(response.responseJSON != NULL){
                    if(apc.PaymentProcessorType == ProcessorUtil.PAT_STRIPE){
                        BillingHistoricalSyncBatch.processProductResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching customers from Stripe.'+ex.getStackTraceString()+'\n'+ex.getMessage());
                apc.requireNextProductSyncRun = false;
                exceptionInExecute = ex;
            }
        } else if(runningObject == BreadwinnerBillingUtil.OBJ_SYNC_PRICE) {
            try {
                Processor_Stripe.FetchRequest fetchRequest = new Processor_Stripe.FetchRequest();
                if(apc.paymentProcessorType == ProcessorUtil.PAT_STRIPE){
                    DateTime lastHourDateTime = apc.hourlyProductSyncLastRun != null ? apc.hourlyProductSyncLastRun.addMinutes(-20) : System.now().addMinutes(-200);
                    fetchRequest.createdGreaterThanOrEqual = String.valueOf(lastHourDateTime);
                    if(apC.lastPriceId != NULL){
                        fetchRequest.starting_after = apC.lastPriceId;
                    }
                    fetchRequest.stripe_limit = '50';
                }
                ProcessorUtil.ResponseObject response = Processor_Billing_Stripe.fetchPrices(apc, fetchRequest);
                if(response.responseJSON != NULL){
                    if(apc.PaymentProcessorType == ProcessorUtil.PAT_STRIPE){
                        BillingHistoricalSyncBatch.processPriceResponse_Stripe(response, apc, requestRecordsCount);
                    }
                }
            } catch (Exception ex) {
                System.debug('Exception occurred while fetching customers from Stripe.'+ex.getStackTraceString()+'\n'+ex.getMessage());
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
            for(BWP_Processor_Config__c ac : BreadwinnerUtil.processorConfigList) {
                appConfigMap.put(ac.Id, ac);
            }
            
            //Lists to seperate failed records and app config records for next run.
            List<BreadwinnerUtil.AppConfig> appConfigNeedToRun = new List<BreadwinnerUtil.AppConfig>();
            List<BreadwinnerUtil.AppConfig> failedAppConfigs = new List<BreadwinnerUtil.AppConfig>();
            
            List<BWP_Processor_Config__c> appConfigNeedToUpdate = new List<BWP_Processor_Config__c>(); //List to save app config records to database.
            
            for(BreadwinnerUtil.AppConfig appConfigWrapper : appConfigUpdateList) {
                Boolean recordExists = 
                    appConfigWrapper.RecordId != NULL &&
                    appConfigMap.containsKey(appConfigWrapper.RecordId);
                BWP_Processor_Config__c appConfigCompleteRecord = recordExists ? appConfigMap.get(appConfigWrapper.RecordId) : new BWP_Processor_Config__c();
                
                if(runningObject.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRODUCT)){
                    System.debug('Product Sync running at '+System.now());
                    if(appConfigWrapper.requireNextProductSyncRun && !appConfigWrapper.needToReconnect) { //if more records
                        // appConfigWrapper.isHourlyCustomerSyncDone = false;
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextProductSyncRun && appConfigWrapper.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        APICallHandler.userInteractionLogPush(TRUE, 'Hourly Sync', 'FINISHED' , 'Object Name: Customer, Syncing Processor: '+appConfigWrapper.paymentProcessorType+' ('+appConfigWrapper.accountName+'), Requested LastSyncDateTime: '+appConfigCompleteRecord.Hourly_Customer_Sync_Last_Run__c+', CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Hourly_Product_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.needToReconnect;
                    appConfigNeedToUpdate.add(appConfigCompleteRecord);
                    
                }else if(runningObject.containsIgnoreCase(BreadwinnerBillingUtil.OBJ_SYNC_PRICE)){
                    
                    if(appConfigWrapper.requireNextPriceSyncRun && !appConfigWrapper.needToReconnect) { //if more records
                        system.debug('need price sync run');
                        // appConfigWrapper.isHourlyPriceSyncDone = false;
                        appConfigNeedToRun.add(appConfigWrapper);
                    } else if(appConfigWrapper.requireNextPriceSyncRun && appConfigWrapper.needToReconnect) { // Failed records
                        failedAppConfigs.add(appConfigWrapper);
                    } else {
                        // appConfigCompleteRecord.Is_Hourly_Payment_Sync_Done__c = true;
                        APICallHandler.userInteractionLogPush(TRUE, 'Hourly Sync', 'FINISHED' , 'Object Name: Payment, Syncing Processor: '+appConfigWrapper.paymentProcessorType+' ('+appConfigWrapper.accountName+'), Requested LastSyncDateTime: '+appConfigCompleteRecord.Hourly_Payment_Sync_Last_Run__c+', CurrentPage Parsed Records: '+requestRecordsCount);
                    }
                    appConfigCompleteRecord.Hourly_Price_Sync_Last_Run__c = System.now();
                    appConfigCompleteRecord.Need_To_Reconnect__c = appConfigWrapper.needToReconnect;
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
            } else if(appConfigNeedToRun.isEmpty() && appConfigNeedToUpdate.size()>0) { //No more batches to run. So start transactions batch.
                if(!BreadwinnerUtil.isBatchRunning(BreadwinnerUtil.CNTX_HOUR_SYNC)) {
                    System.debug('Ready for Payment sync');
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
