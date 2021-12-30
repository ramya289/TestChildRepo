@isTest
/*
* This class is to create data for test classes. It's created for more resuability.
* All test methods will be here. This is the only the class for all test cases for all classes.
*/
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