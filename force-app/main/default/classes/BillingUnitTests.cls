@isTest
public class BillingUnitTests {

    @TestVisible
    private static List<BWP_Product__c> products(Integer count) {
        List<BWP_Product__c> products = new List<BWP_Product__c> ();
        for (Integer i = 1; i <= count; i++) {

            BWP_Product__c product = new BWP_Product__c(
                Name = 'Test Product'
            );
            products.add(product);
        }
        insert products;
        return products;
    }
}