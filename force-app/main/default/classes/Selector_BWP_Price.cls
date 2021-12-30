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
                    BWP_Price__c.Processor_Id__c,
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

    public List<BWP_Price__c> selectById(Set<String> idSet){
        QueryBuilder qb = newQueryBuilder();
        qb.setCondition('Id IN :idSet');

        return (List<BWP_Price__c>) Database.query(qb.toSOQL());
    }

    public List<BWP_Price__c> selectByProcessorId(Set<String> idSet, List<String> relatedFields){
        QueryBuilder qb = newQueryBuilderWithRelatedFields(relatedFields);
        qb.setCondition('Processor_Id__c IN :idSet');
        return (List<BWP_Price__c>) Database.query(qb.toSOQL());
    }

    public List<BWP_Price__c> selectByProcessorProductId(Set<Id> idSet, Integer lim){
        QueryBuilder qb = newQueryBuilder();
        qb.setCondition('Product__c IN :idSet');
        if (lim != null){
            qb.setLimit(lim);
        }
        return (List<BWP_Price__c>) Database.query(qb.toSOQL());
    }

    public List<BWP_Price__c> selectByProcessorOrgId(String id, Integer lim){
        return selectByProcessorOrgId(new Set<String>{id}, lim);
    }

    /**
     * Queries the BWP_Price__c object for records that match the Processor_Org_Id__c
     *
     * @param idSet Set of Ids to be filtered
     * @param lim number of rows that should be returned.  All rows are return if mull
     *
     * @return List<BWP_Price__c>
     */
    public List<BWP_Price__c> selectByProcessorOrgId(Set<String> idSet, Integer lim){
        QueryBuilder qb = newQueryBuilder();
        qb.setCondition('Processor_Org_Id__c IN :idSet');
        if (lim != null){
            qb.setLimit(lim);
        }
        return (List<BWP_Price__c>) Database.query(qb.toSOQL());
    }

    public List<BWP_Price__c> selectWithLimit(Integer lim){
        QueryBuilder qb = newQueryBuilder();
        if (lim != null){
            qb.setLimit(lim);
        }
        return (List<BWP_Price__c>) Database.query(qb.toSOQL());
    }

    public Integer selectCount(String whereString, Integer lim){
        // For the count queries just return zero instead of throwing an exception
        if(!Schema.SObjectType.BWP_Price__c.isAccessible()){
            return 0;
        }
        String qry = 'SELECT COUNT() FROM BWP_Price__c';
        if (String.isNotBlank(whereString)){
            qry += ' WHERE ' + whereString;
        }
        if (lim != null){
            qry += ' LIMIT ' + String.valueOf(lim);
        }
        System.debug('qry: ' + qry);
        return Database.countQuery(qry);
    }
}