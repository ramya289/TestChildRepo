public with sharing class BreadwinnerBilling {
    public List<BreadwinnerUtil.AppConfig> stripeAppConfigList          {get; set;}
    public BreadwinnerUtil.AppConfig appC                               {get; set;}
    public Boolean isStripeConnected                                    {get; set;}
    public Boolean isProductsListEmpty                                  {get; set;}
    public List<Product> productsList                                   {get; set;}
    public Boolean showProducts                                         {get; set;}
    public Boolean showRemoteSitesError                                 {get; set;}
    public BreadwinnerBilling() {
        stripeAppConfigList = new List<BreadwinnerUtil.AppConfig>();
        for(BWP_Processor_Config__c appC : BreadwinnerUtil.processorConfigList){
            if(appC.Payment_Processor_Type__c == 'Stripe')
                stripeAppConfigList.add(BreadwinnerUtil.getProcessorConfigWrapper(appC));
        }
        appC = stripeAppConfigList.size() > 0?stripeAppConfigList[0]: new BreadwinnerUtil.AppConfig();
        isStripeConnected = stripeAppConfigList.size() > 0;
        productsList = new List<Product>();
        isProductsListEmpty = true;
        showProducts = false;
        showRemoteSitesError = false;
        checkRemoteSites();
    }
    public void checkRemoteSites() {
        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            HttpResponse res = new HttpResponse();
            if(!Test.isRunningTest()) {
                req.setEndpoint('https://connect.stripe.com');
                res = new Http().send(req);
                req.setEndpoint('https://api.stripe.com');
                res = new Http().send(req);
            } 
        } catch(Exception e) {
            if(e.getTypeName() != null && e.getTypeName() == 'System.CalloutException' && e.getMessage() != null && e.getMessage().containsIgnoreCase('Unauthorized endpoint')) {
                showRemoteSitesError = true;
            }
        } 
    }
    public void fetchProducts() {
        BreadwinnerUtil.AppConfig ac = (appC.accessToken!=NULL)?CryptoUtil.decryptSecrets(appC):new BreadwinnerUtil.AppConfig();
        String endPoint = Processor_Stripe.stripeBaseUrlv1 + '/products?limit=15';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endPoint);
        if(ac!=NULL) req.setHeader('Authorization', 'Bearer ' + ac.accessToken);
        req.setMethod('GET');
        try {
            Http h = new Http();
            HttpResponse res = new HttpResponse();
            if(!Test.isRunningTest()) {
                res = h.send(req);
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"object": "list","data": [{"id": "{PROD_ID}","object": "product","active": true,"attributes": [],"created": 1626790311,"description": "QBD test product","images": [],"livemode": false,"metadata": {},"name": "Test QBD","package_dimensions": null,"shippable": null,"statement_descriptor": null,"tax_code": null,"type": "service","unit_label": null,"updated": 1632465361,"url": null}],"has_more": false,"url": "/v1/products"}');
                res.setStatusCode(200);
            }
            if(res.getStatusCode() == 200) {
                System.debug('res.getbody() ::: '+res.getbody());
                
                JSONParser parser = JSON.createParser(res.getbody());
                ProductsResponse responseData = (ProductsResponse) parser.readValueAs(ProductsResponse.class);
                List<BWP_Product__c> prodsList = new List<BWP_Product__c>();
                for(Product c : responseData.data) {
                    BWP_Product__c p = new BWP_Product__c();
                    p.Name = c.name;
                    p.Active__c = Boolean.valueof(c.active);
                    p.Type__c = c.type;
                    p.Description__c = c.description;
                    c.createdDate = DateTime.newInstance((long)(c.created) * 1000);
                    c.updatedDate = DateTime.newInstance((long)(c.updated) * 1000);
                    p.Created_Date_in_Processor__c = c.createdDate;
                    p.Updated_Date_in_Processor__c = c.updatedDate;
                    p.Processor_Id__c = c.id;
                    prodsList.add(p);
                }
                productsList = responseData.data;
                System.debug('productsList ::: '+productsList);
                if(responseData.data.size()>0 && prodsList.size()>0) {
                    upsert prodsList Processor_Id__c;
                    isProductsListEmpty = false;
                    showProducts = true;
                } else {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, ' No Products found.'));
                }
            } else { // Failed
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ' Error occurred while fetching Products. Please try again or contact Breadwinner Support.'));
            } 
        } catch(Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ' Error occurred  while fetching Products. Please try again or contact Breadwinner Support.'));
            System.debug('Products fetching failed.'+ex.getMessage()+'/n'+ex.getStackTraceString());            
        }
    }
    public class ProductsResponse {
        public List <Product> data         {get;set;}
    }
    public class Product {
        public String id                        {get; set;}
        public String name                      {get; set;}
        public String active                    {get; set;}
        public String description               {get; set;}
        public String type                      {get; set;}
        public Long created                     {get; set;}
        public Datetime createdDate             {get; set;}
        public Long updated                     {get; set;}
        public Datetime updatedDate             {get; set;}
    }
}