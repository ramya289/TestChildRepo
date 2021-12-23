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
}
