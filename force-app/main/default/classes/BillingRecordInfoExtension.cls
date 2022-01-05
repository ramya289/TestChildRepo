public with sharing class BillingRecordInfoExtension {
    private static Selector_BWP_Product selectorProduct = new Selector_BWP_Product();
    private static Selector_BWP_Price selectorPrice = new Selector_BWP_Price();

    public ID recordId                                                  {get; set;}
    public Sobject sObj                                                 {get; set;}
    String sObjName;
    public String appNameSpace;
    public Boolean showBWLayout                                         {get; set;}
    public BWP_Product__c productInfo                                   {get; set;}
    public List<BWP_Price__c> pricesList                                {get; set;}
    public BWP_Processor_Config__c config                               {get; set;}    

    public BillingRecordInfoExtension(ApexPages.StandardController stdController) {
        pricesList = new List<BWP_Price__c>();
        showBWLayout = ApexPages.currentPage().getParameters().get('showBWLayout')!=null &&Boolean.valueof(ApexPages.currentPage().getParameters().get('showBWLayout'))? true:false;
        if(!showBWLayout){
            showBWLayout = (Apexpages.CurrentPage().getparameters().get('sfdc.override')!=null) ? (Apexpages.CurrentPage().getparameters().get('sfdc.override')=='1') : FALSE;
        }
        appNameSpace = BreadwinnerUtil.namespaceApi;
        recordId = String.escapeSingleQuotes(stdController.getId());
        sObj = recordId.getsobjecttype().newSObject();
        sObjName = recordId.getsobjecttype().getDescribe().getname();
        config = BreadwinnerUtil.processorConfigList.size() > 0 ? BreadwinnerUtil.processorConfigList[0] : new BWP_Processor_Config__c();

        if(showBWLayout){
            QueryBuilder qb;
            if(sObjName == appNameSpace+'BWP_Product__c'){
                qb = new QueryBuilder(BWP_Product__c.SObjectType, true, true, true);
                List<Schema.SObjectField> fieldsList = Selector_BWP_Product.FIELD_LIST;
                qb.addSObjectFields(fieldsList);
            } 
            // else if(sObjName == appNameSpace+'BWP_Price__c'){
            //     qb = new QueryBuilder(BWP_Price__c.SObjectType, true, true, true);
            //     qb.addSObjectFields(BWP_Price__c.SObjectType.getDescribe().fields.getMap().values());
            // }
            qb.setCondition('Id=:recordId');
            qb.setLimit(1);
            System.debug('qb.toSOQL() ::: '+qb.toSOQL());
            sObj = Database.query(qb.toSOQL());
            String processorId = String.valueOf(sobj.get('Processor_Org_Id__c'));
            config = BreadwinnerUtil.getProcessorConfig(processorId);
            if(sObjName == appNameSpace+'BWP_Product__c'){
                productInfo = (BWP_Product__c)sobj;
                pricesList = selectorPrice.selectByProcessorProductId(new Set<Id>{recordId}, 1000);
            }
        }
    }
}