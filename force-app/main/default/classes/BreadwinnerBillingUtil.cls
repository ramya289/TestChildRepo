public with sharing class BreadwinnerBillingUtil {

    public static final String OBJ_SYNC_PRODUCT = 'Product';
    public static final String OBJ_SYNC_PRICE = 'Price';

    public static final String CNTX_BB_HIST_SYNC = 'BillingHistoricalSyncBatch';
    public static final String BB_ADMIN_PS_NAME = 'Breadwinner_Billing_Admin_User';

    // This method is used to get the object name for Batch class
    public static String findNextSyncName(String currentRunningObjectName){
        String nextRunningObjectName;
        if(String.isNotBlank(currentRunningObjectName)){
            if(currentRunningObjectName == OBJ_SYNC_PRODUCT){
                nextRunningObjectName = OBJ_SYNC_PRICE;
            }
        }
        return nextRunningObjectName;
    }

    public static List<BWP_Processor_Config__c> processorConfigList{
        get{
            if(processorConfigList == null){
                QueryBuilder qb = new QueryBuilder(BWP_Processor_Config__c.SObjectType, true, true, true);
                List<Schema.SObjectField> fieldsList = Selector_BWP_ProcessorConfig.FIELD_LIST;
                List<Schema.SObjectField> billingFieldsList = new List<Schema.SObjectField>{BWP_Processor_Config__c.Regular_Product_Sync_Last_Run__c, BWP_Processor_Config__c.Regular_Price_Sync_Last_Run__c,BWP_Processor_Config__c.Historical_Product_Sync_Last_Run__c, BWP_Processor_Config__c.Historical_Price_Sync_Last_Run__c};
                fieldsList.addAll(billingFieldsList);
                qb.addSObjectFields(fieldsList);
                processorConfigList = (List<BWP_Processor_Config__c>) Database.query(qb.toSOQL());
            }
            return processorConfigList;
        }
        private set;
    }

    public class BillingAppConfig {
        public BreadwinnerUtil.AppConfig appconfig                      {get; set;}
        public Datetime regularProductSyncLastRun                       {get; set;}
        public Datetime regularPriceSyncLastRun                         {get; set;}
        public String lastProductId                                     {get; set;}
        public String lastPriceId                                       {get; set;}
        public Boolean requireNextProductSyncRun                        {get; set;}
        public Boolean requireNextPriceSyncRun                          {get; set;}
    }
    public static BillingAppConfig getProcessorConfigWrapper(BWP_Processor_Config__c appC) {
        BillingAppConfig ac = new BillingAppConfig();
        try{
            ac.appconfig = BreadwinnerUtil.getProcessorConfigWrapper(appC);
            ac.regularProductSyncLastRun = appC.Regular_Product_Sync_Last_Run__c;
            ac.regularPriceSyncLastRun = appC.Regular_Price_Sync_Last_Run__c;
            ac.requireNextProductSyncRun = false;
            ac.requireNextPriceSyncRun = false;
        }
        catch(Exception ex) {
            System.debug('Error occurred while parsing custom setting:AppConfig. '+ex.getStackTraceString());
            APICallHandler.userInteractionLogPush(TRUE, 'App Config', 'ERROR' , 'Error occured while parsing custom setting:AppConfig. '+ex.getStackTraceString());
        }
        return ac;
    }
}