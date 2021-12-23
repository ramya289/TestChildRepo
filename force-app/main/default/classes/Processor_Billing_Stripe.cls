public with sharing class Processor_Billing_Stripe {
    private static Selector_BWP_Product selectorProduct = new Selector_BWP_Product();
    private static Selector_BWP_Price selectorPrice = new Selector_BWP_Price();
    
    public static ProcessorUtil.ResponseObject fetchProducts(BreadwinnerUtil.AppConfig apcWrapper, Processor_Stripe.FetchRequest request) {
        ProcessorUtil.ResponseObject response = new ProcessorUtil.ResponseObject();
        response.errors = new List<ProcessorUtil.Error>();
        Processor_Stripe.FetchRequest filters = request;//(Processor_Stripe.FetchRequest)System.JSON.deserialize(requestJSON, Processor_Stripe.FetchRequest.class);
        String endPoint = Processor_Stripe.stripeBaseUrlv1 + '/products';
        if (String.isNotBlank(filters.stripe_limit)) {
            String encodedLimit = getURLEncodeData(filters.stripe_limit);
            //make max limit to 50 to reduce head size and DML rows issues.
            endPoint += '?limit=' + (Integer.valueOf(encodedLimit) >= 50 ? 50 : Integer.valueOf(encodedLimit));
        } else {
            //if no limit is supplied, 10 will be applied by default.
            endPoint += '?limit=50';
        }
        if (String.isNotBlank(filters.starting_after)) {
            endPoint += '&starting_after=' + filters.starting_after;
        }
        if (String.isNotBlank(filters.createdGreaterThanOrEqual)) {
            endPoint += '&created[gte]=' + (DateTime.valueOf(filters.createdGreaterThanOrEqual).getTime()) / 1000;
        }
        HttpResponse res = APICallHandler.getList(apcWrapper, 'GET', endPoint, '');
        response.status = String.valueOf(res.getStatusCode());

        if (res.getStatusCode() == 200) {
            system.debug('response---------'+res.getBody());
            FetchResponse fetchResponse = new FetchResponse();
            fetchResponse = parseProducts(res.getBody());
            response.responseJSON = JSON.serializePretty(fetchResponse);

        } else {
            apcWrapper.needToReconnect = true;
            String Action_Type = ProcessorUtil.getLogAction(apcWrapper.currentRunningClassContext, 'Fetching Products');
            APICallHandler.userInteractionLogPush(true, Action_Type, 'ERROR' , 'Response for Processor Org Name('+apcWrapper.accountName+'): Status Code: '+res.getStatusCode()+' Response Body: '+res.getBody() );

            Map<String, Object> responseFromStripe = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> error = (Map<String, Object>)responseFromStripe.get('error');
            if(error != NULL)
                response.errors.add(formatError(error, String.valueOf(res.getStatusCode())));
        }

        return response;
    }
    public static ProcessorUtil.ResponseObject fetchPrices(BreadwinnerUtil.AppConfig apcWrapper, Processor_Stripe.FetchRequest request) {
        ProcessorUtil.ResponseObject response = new ProcessorUtil.ResponseObject();
        response.errors = new List<ProcessorUtil.Error>();
        Processor_Stripe.FetchRequest filters = request;
        String endPoint = Processor_Stripe.stripeBaseUrlv1 + '/prices';
        if (String.isNotBlank(filters.stripe_limit)) {
            String encodedLimit = getURLEncodeData(filters.stripe_limit);
            //make max limit to 50 to reduce head size and DML rows issues.
            endPoint += '?limit=' + (Integer.valueOf(encodedLimit) >= 50 ? 50 : Integer.valueOf(encodedLimit));
        } else {
            //if no limit is supplied, 10 will be applied by default.
            endPoint += '?limit=50';
        }
        if (String.isNotBlank(filters.starting_after)) {
            endPoint += '&starting_after=' + filters.starting_after;
        }
        if (String.isNotBlank(filters.createdGreaterThanOrEqual)) {
            endPoint += '&created[gte]=' + (DateTime.valueOf(filters.createdGreaterThanOrEqual).getTime()) / 1000;
        }
        HttpResponse res = APICallHandler.getList(apcWrapper, 'GET', endPoint, '');
        response.status = String.valueOf(res.getStatusCode());

        if (res.getStatusCode() == 200) {
            system.debug('response---------'+res.getBody());
            FetchResponse fetchResponse = new FetchResponse();
            fetchResponse = parsePrices(res.getBody());
            response.responseJSON = JSON.serializePretty(fetchResponse);

        } else {
            apcWrapper.needToReconnect = true;
            String Action_Type = ProcessorUtil.getLogAction(apcWrapper.currentRunningClassContext, 'Fetching Prices');
            APICallHandler.userInteractionLogPush(true, Action_Type, 'ERROR' , 'Response for Processor Org Name('+apcWrapper.accountName+'): Status Code: '+res.getStatusCode()+' Response Body: '+res.getBody() );

            Map<String, Object> responseFromStripe = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> error = (Map<String, Object>)responseFromStripe.get('error');
            if(error != NULL)
                response.errors.add(formatError(error, String.valueOf(res.getStatusCode())));
        }

        return response;
    }
    public static FetchResponse parseProducts(String responseBody) {
        Map<String, Product.StripeProduct> stripeIdProducttMap = new Map<String, Product.StripeProduct>();
        FetchResponse response = new FetchResponse();
        try{	
            String responseStr = Processor_Stripe.replaceStripeWords(responseBody);	
            JSONParser parser = JSON.createParser(responseStr);	
            ProductsResponse responseData = (ProductsResponse) parser.readValueAs(ProductsResponse.class);
            if(responseData.data != NULL){	
                Boolean hasMoreRecords = responseData.has_more;	
                String lastProductId = '';
                for (Product.StripeProduct pro : responseData.data) {
                    stripeIdProducttMap.put(pro.Id,pro);
                    lastProductId = pro.id;
                }
                if(hasMoreRecords){	
                    system.debug('hasmore records');
                    response.requireNextRun = TRUE;
                    response.last_record_id = lastProductId;
                }
                else{
                    response.requireNextRun = FALSE;
                    response.last_record_id = '';
                }	
            }
            else if(responseData.data == NULL){
                system.debug('single payment');
                Product.StripeProduct product = (Product.StripeProduct) JSON.deserialize(responseStr, Product.StripeProduct.Class);
                stripeIdProducttMap.put(product.id, product);
            }	
            response.productMapById = stripeIdProducttMap;
        } catch(Exception ex) {
            System.debug('Products Sync failed for while parsing. \n' +ex.getStackTraceString());
            APICallHandler.userInteractionLogPush(true, 'Product Sync', 'ERROR' , 'Products Sync failed for while parsing. \n' +ex.getMessage());
        }
        return response;
    }
    public static FetchResponse parsePrices(String responseBody) {
        Map<String, Product.StripePrice> stripeIdPriceMap = new Map<String, Product.StripePrice>();
        FetchResponse response = new FetchResponse();
        try{	
            String responseStr = Processor_Stripe.replaceStripeWords(responseBody);	
            JSONParser parser = JSON.createParser(responseStr);	
            PricesResponse responseData = (PricesResponse) parser.readValueAs(PricesResponse.class);
            if(responseData.data != NULL){	
                Boolean hasMoreRecords = responseData.has_more;	
                String lastPriceId = '';
                for (Product.StripePrice pro : responseData.data) {
                    stripeIdPriceMap.put(pro.Id,pro);
                    lastPriceId = pro.id;
                }
                if(hasMoreRecords){	
                    system.debug('hasmore records');
                    response.requireNextRun = TRUE;
                    response.last_record_id = lastPriceId;
                }
                else{
                    response.requireNextRun = FALSE;
                    response.last_record_id = '';
                }	
            }
            else if(responseData.data == NULL){
                system.debug('single payment');
                Product.StripePrice product = (Product.StripePrice) JSON.deserialize(responseStr, Product.StripePrice.Class);
                stripeIdPriceMap.put(product.id, product);
            }	
            response.priceMapById = stripeIdPriceMap;
        } catch(Exception ex) {
            System.debug('Products Sync failed for while parsing. \n' +ex.getStackTraceString());
            APICallHandler.userInteractionLogPush(true, 'Product Sync', 'ERROR' , 'Products Sync failed for while parsing. \n' +ex.getMessage());
        }
        return response;
    }
    public static void syncProducts(Map<String, Product.StripeProduct> stripeProductMapById, BreadwinnerUtil.AppConfig apc){
        Map<String, BWP_Product__c> upsertMapByRefId = new Map<String, BWP_Product__c>();
        Map<String, BWP_Product__c> existingSFProductsMap = new Map<String,BWP_Product__c>();
        try {
            for(BWP_Product__c product : selectorProduct.selectByProcessorId(stripeProductMapById.keySet(), new List<String>())) {
                BWP_Product__c pro = new BWP_Product__c(id = product.id, Processor_Id__c = product.Processor_Id__c);
                existingSFProductsMap.put(pro.Processor_Id__c, pro);
            }
            
            for (Product.StripeProduct pw : stripeProductMapById.values()) {
                BWP_Product__c productSf = existingSFProductsMap.get(pw.id) != null ? existingSFProductsMap.get(pw.id) : new BWP_Product__c();
                productSf = constructStripeProduct(productSf, pw, apc);
                upsertMapByRefId.put(productSf.Processor_Id__c, productSf);
            }

            System.debug('upsertMapByRefId :::: '+upsertMapByRefId);
            if(!upsertMapByRefId.isEmpty()){
                SecurityUtil.databaseUpsert(upsertMapByRefId.values());
            }
        } catch (Exception ex) {
            System.debug('Products Sync failed for while syncing. \n' +ex.getStackTraceString());
            APICallHandler.userInteractionLogPush(true, 'Product Sync', 'ERROR' , 'Products Sync failed for while syncing. \n' +ex.getMessage());
        }
    }
    public static void syncPrices(Map<String, Product.StripePrice> stripePriceMapById, BreadwinnerUtil.AppConfig apc){
        Map<String, BWP_Price__c> upsertMapByRefId = new Map<String, BWP_Price__c>();
        Map<String, BWP_Price__c> existingSFProductsMap = new Map<String,BWP_Price__c>();
        try {
            for(BWP_Price__c product : selectorPrice.selectByProcessorId(stripePriceMapById.keySet(), new List<String>())) {
                BWP_Price__c pro = new BWP_Price__c(id = product.id, Processor_Id__c = product.Processor_Id__c);
                existingSFProductsMap.put(pro.Processor_Id__c, pro);
            }

            Set<String> productIdSet = new Set<String>();
            for (Product.StripePrice pw : stripePriceMapById.values()) {
                productIdSet.add(pw.product);
            }
            // Create a map of products
            Map<String, BWP_Product__c> productMapByProcessorProductId = new Map<String, BWP_Product__c>();
            List<BWP_Product__c> productList = selectorProduct.selectByProcessorId(productIdSet,new List<String>());
            for (BWP_Product__c product : productList) {
                productMapByProcessorProductId.put(product.Processor_Id__c, product);
            }
            
            for (Product.StripePrice pw : stripePriceMapById.values()) {
                BWP_Price__c priceSf = existingSFProductsMap.get(pw.id) != null ? existingSFProductsMap.get(pw.id) : new BWP_Price__c();
                BWP_Product__c product = productMapByProcessorProductId.get(pw.product);
                if(product != NULL) priceSf.Product__c = product.id;
                priceSf = constructStripePrice(priceSf, pw, apc);
                upsertMapByRefId.put(priceSf.Processor_Id__c, priceSf);
            }

            System.debug('upsertMapByRefId :::: '+upsertMapByRefId);
            if(!upsertMapByRefId.isEmpty()){
                SecurityUtil.databaseUpsert(upsertMapByRefId.values());
            }
        } catch (Exception ex) {
            System.debug('Products Sync failed for while syncing. \n' +ex.getStackTraceString());
            APICallHandler.userInteractionLogPush(true, 'Product Sync', 'ERROR' , 'Products Sync failed for while syncing. \n' +ex.getMessage());
        }
    }
    private static BWP_Product__c constructStripeProduct(BWP_Product__c productSf, Product.StripeProduct pw, BreadwinnerUtil.AppConfig appConfig){
        System.debug('PW Wrapper :::: '+pw);
        productSf.Active__c = pw.active;
        if(pw.created != null) productSf.Created_Date_in_Processor__c = DateTime.newInstance((long)(pw.created) * 1000);
        productSf.Created_Via__c = BreadwinnerUtil.getCreatedViaValue(appConfig.currentRunningClassContext);
        productSf.Description__c = pw.description;
        productSf.Livemode__c = pw.livemode;
        productSf.Name = pw.name;
        productSf.Product_Name__c = pw.name;
        productSf.Processor_Id__c = pw.Id;
        productSf.Processor_Org_Id__c = appConfig.accountId;
        productSf.Processor_Org_Name__c = appConfig.accountName;
        productSf.Processor_Type__c = appConfig.PaymentProcessorType;
        productSf.Type__c = pw.stripe_type;
        if(pw.updated != null) productSf.Updated_Date_in_Processor__c = DateTime.newInstance((long)(pw.updated) * 1000);
        return productSf;
    }
    private static BWP_Price__c constructStripePrice(BWP_Price__c priceSf, Product.StripePrice pw, BreadwinnerUtil.AppConfig appConfig){
        System.debug('PW Wrapper :::: '+pw);
        priceSf.Processor_Id__c = pw.Id;
        priceSf.Active__c = pw.active;
        if(pw.created != null) priceSf.Created_Date_in_Processor__c = DateTime.newInstance((long)(pw.created) * 1000);
        priceSf.Livemode__c = pw.livemode;
        priceSf.Created_Via__c = BreadwinnerUtil.getCreatedViaValue(appConfig.currentRunningClassContext);
        priceSf.Currency__c = pw.stripe_currency;
        priceSf.Processor_Id__c = pw.Id;
        priceSf.Processor_Org_Id__c = appConfig.accountId;
        priceSf.Processor_Type__c = appConfig.PaymentProcessorType;
        if(pw.stripe_type != null) priceSf.Type__c = pw.stripe_type;
        if(pw.recurring != NULL){
            priceSf.Recurring_Interval__c = pw.recurring.interval;
            priceSf.Recurring_Interval_Count__c = pw.recurring.interval_count;
        }
        if(pw.unit_amount != NULL) priceSf.Unit_Amount__c = pw.unit_amount/100;
        return priceSf;
    }
    private class ProductsResponse {
        public Boolean has_more;
        public List<Product.StripeProduct> data;
    }
    private class PricesResponse {
        public Boolean has_more;
        public List<Product.StripePrice> data;
    }
    public class FetchResponse {
        public String last_record_id;
        public boolean requireNextRun;
        public Map<String, Product.StripeProduct> productMapById;
        public Map<String, Product.StripePrice> priceMapById;
    }
    private static String getURLEncodeData(String data) {
        return EncodingUtil.urlEncode(data, 'UTF-8');
    }
    private static ProcessorUtil.Error formatError(Map<String, Object> error, String statusCode){
        String errCode = error.get('code') != null ? error.get('code').toString() : statusCode;
        String errMess = error.get('message') != null ? error.get('message').toString() : '';
        return new ProcessorUtil.Error(errCode,errMess);
    }
}
