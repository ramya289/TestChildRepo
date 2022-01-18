public with sharing class Selector_BWP_Price extends QuerySelector {
    // Core list of fields
    public static List<Schema.SObjectField> FIELD_LIST {
        get {
            if (FIELD_LIST == null) {
                FIELD_LIST = new List<Schema.SObjectField>{
                    BWP_Price__c.Id,
                    BWP_Price__c.Name,
                    BWP_Price__c.Active__c,
                    BWP_Price__c.Created_Date_in_Processor__c,
                    BWP_Price__c.Created_Via__c,
                    BWP_Price__c.Currency__c,
                    BWP_Price__c.Price_Id__c,
                    BWP_Price__c.Processor_Org_Id__c,
                    BWP_Price__c.Product__c,
                    BWP_Price__c.Recurring_Interval__c,
                    BWP_Price__c.Recurring_Interval_Count__c,
                    BWP_Price__c.Type__c,
                    BWP_Price__c.Unit_Amount__c
                };
            }
            return FIELD_LIST;
        }
        private set;
    }

    public Selector_BWP_Price() {
        this(true, true, true);
    }
    public Selector_BWP_Price(Boolean enforceRead, Boolean enforceFLS, Boolean throwFLSException) {
        super(enforceRead, enforceFLS, throwFLSException);
    }
    
    public override Schema.SObjectType getSObjectType() {
        return BWP_Price__c.SObjectType;
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

    public List<BWP_Price__c> selectByPriceId(Set<String> idSet, List<String> relatedFields){
        QueryBuilder qb = newQueryBuilderWithRelatedFields(relatedFields);
        qb.setCondition('Price_Id__c IN :idSet');
        return (List<BWP_Price__c>) Database.query(qb.toSOQL());
    }
}