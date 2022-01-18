public with sharing class Selector_BWP_Product extends QuerySelector {
    // Core list of fields
    public static List<Schema.SObjectField> FIELD_LIST {
        get {
            if (FIELD_LIST == null) {
                // We are getting a strange SecurityUtil.FLSException: Access Denied: DML_READ on BWP_Product__c.LastViewedDate
                // if we do this FIELD_LIST = BWP_Product__c.SObjectType.getDescribe().fields.getMap().values() so hard coding it;
                FIELD_LIST = new List<Schema.SObjectField>{
                    BWP_Product__c.Id,
                    BWP_Product__c.Name,
                    BWP_Product__c.Active__c,
                    BWP_Product__c.Created_Date_in_Processor__c,
                    BWP_Product__c.Created_Via__c,
                    BWP_Product__c.Description__c,
                    BWP_Product__c.Product_Id__c,
                    BWP_Product__c.Processor_Org_Id__c,
                    BWP_Product__c.Product_Name_Full__c,
                    BWP_Product__c.Type__c
                };
            }
            return FIELD_LIST;
        }
        private set;
    }

    public Selector_BWP_Product() {
        this(true, true, true);
    }
    public Selector_BWP_Product(Boolean enforceRead, Boolean enforceFLS, Boolean throwFLSException) {
        super(enforceRead, enforceFLS, throwFLSException);
    }
    
    public override Schema.SObjectType getSObjectType() {
        return BWP_Product__c.SObjectType;
    }

    private List<Schema.SObjectField> sObjectFieldList;
    public override List<Schema.SObjectField> getSObjectFieldList() {
        return sObjectFieldList != null ? sObjectFieldList : FIELD_LIST;
    }
    /**
     * Allows the calling class to override the default FIELD_LIST
     * @param fieldList list of field that will be passed into the query
     */
    public void setSObjectFieldList(List<Schema.SObjectField> fieldList){
        this.sObjectFieldList = fieldList;
    }

    private String orderBy;
    public override String getOrderBy() {
        return String.isBlank(orderBy) ? 'Name ASC' : orderBy;
    }

    public List<BWP_Product__c> selectByProductId(Set<String> idSet, List<String> relatedFields){
        QueryBuilder qb = newQueryBuilderWithRelatedFields(relatedFields);
        qb.setCondition('Product_Id__c IN :idSet');
        return (List<BWP_Product__c>) Database.query(qb.toSOQL());
    }
}