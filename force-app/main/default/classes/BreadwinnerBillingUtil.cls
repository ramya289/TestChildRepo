public with sharing class BreadwinnerBillingUtil {

    public static final String OBJ_SYNC_PRODUCT = 'Product';
    public static final String OBJ_SYNC_PRICE = 'Price';

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
                List<Schema.SObjectField> billingFieldsList = new List<Schema.SObjectField>{BWP_Processor_Config__c.Hourly_Product_Sync_Last_Run__c, BWP_Processor_Config__c.Hourly_Price_Sync_Last_Run__c,BWP_Processor_Config__c.Historical_Product_Sync_Last_Run__c, BWP_Processor_Config__c.Historical_Price_Sync_Last_Run__c};
                fieldsList.addAll(billingFieldsList);
                qb.addSObjectFields(fieldsList);
                processorConfigList = (List<BWP_Processor_Config__c>) Database.query(qb.toSOQL());
            }
            return processorConfigList;
        }
        set;
    }

    // public static BWP_Processor_Config__c getProcessorConfig(String processorId){
    //     List<BWP_Processor_Config__c> processorConfig = selectorProcessorConfig.selectByProcessorId(new Set<String>{processorId});
    //     return processorConfig.size()>0 ? processorConfig[0] : new BWP_Processor_Config__c();
    // }

    public class BillingAppConfig {
        public BreadwinnerUtil.AppConfig appconfig               {get; set;}
        public Datetime hourlyProductSyncLastRun            {get;set;}
    }
    public static BillingAppConfig getProcessorConfigWrapper(BWP_Processor_Config__c appC) {
        appC = appC != null ? appC : new BWP_Processor_Config__c();
        BillingAppConfig ac = new BillingAppConfig();
        try{
            ac.appconfig = BreadwinnerUtil.getProcessorConfigWrapper(appC);
            ac.hourlyProductSyncLastRun = appC.Hourly_Product_Sync_Last_Run__c;
        }
        catch(Exception ex) {
            System.debug('Error occurred while parsing custom setting:AppConfig. '+ex.getStackTraceString());
            APICallHandler.userInteractionLogPush(TRUE, 'App Config', 'ERROR' , 'Error occured while parsing custom setting:AppConfig. '+ex.getStackTraceString());
        }
        return ac;
    }
}