/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var products = {
    "products": [
        {
            "id": 1,
            "name": "Sunglasses",
            "description": "Add a modern touch to your outfits with these sleek aviator sunglasses.",
            "price": 19,
            "categories": ["accessories"]
        },
        {
            "id": 2,
            "name": "Tank Top",
            "description": "Perfectly cropped cotton tank, with a scooped neckline.",
            "price": 18,
            "categories": ["clothing", "tops"]
        },
        {
            "id": 3,
            "name": "Watch",
            "description": "This gold-tone stainless steel watch will work with most of your outfits.",
            "price": 109,
            "categories": ["accessories"]
        },
        {
            "id": 4,
            "name": "Loafers",
            "description": "A neat addition to your summer wardrobe.",
            "price": 89,
            "categories": ["footwear"]
        },
        {
            "id": 5,
            "name": "Hairdryer",
            "description": "This lightweight hairdryer has 3 heat and speed settings. It's perfect for travel.",
            "price": 24,
            "categories": ["hair", "beauty"]
        },
        {
            "id": 6,
            "name": "Candle Holder",
            "description": "This small but intricate candle holder is an excellent gift.",
            "price": 18,
            "categories": ["decor", "home"]
        },
        {
            "id": 7,
            "name": "Salt & Pepper Shakers",
            "description": "Add some flavor to your kitchen.",
            "price": 18,
            "categories": ["kitchen"]
        },
        {
            "id": 8,
            "name": "Bamboo Glass Jar",
            "description": "This bamboo glass jar can hold 57 oz (1.7 l) and is perfect for any kitchen.",
            "price": 5,
            "categories": ["kitchen"]
        },
        {
            "id": 9,
            "name": "Mug",
            "description": "A simple mug with a mustard interior.",
            "price": 8,
            "categories": ["kitchen"]
        }
    ]
};

var pathsuffix = context.getVariable("proxy.pathsuffix");

if(pathsuffix !=null && (pathsuffix.equals("/products") || pathsuffix.equals("/products/"))){
  response.content = JSON.stringify(products);
}
else{
  var productResponse = {products: []};
  var productId = context.getVariable("id");
  if(productId != null && productId != ""){
    for (var i=0; i < products.products.length; i++){
      var product = products.products[i];
      if(productId == product.id){
        productResponse.products.push(product)
      }
    }
  }
  response.content = JSON.stringify(productResponse);
}
