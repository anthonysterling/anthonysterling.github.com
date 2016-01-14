---
layout: post
title: An introduction to moltin's Product Modifiers and Variants
date: 2016-01-04
tags: [moltin, API]
---

Through the use of modifiers and variants, you can add additional fields to your products. These fields allow you to create variations of your existing products. For example, if you are selling T-shirts, you can add modifiers for the size and the colour. Once you add variations - these are the possible values for each modifier - you can sell each variant product individually.

Here's a quick rundown of what we'll be covering:-

- Viewing account information
- Creating a product
- Listing categories
- Listing taxes
- Listing products
- Listing product modifiers
- Creating a product modifier
- Creating a product modifier's variant
- Adding a product to a cart
- Adding a product variant to a cart
- Viewing a cart

We'll be using a combination of [jq][1] and [cURL][2] in this post, jq is completely optional here as I'm just using it to prettify the JSON response returned from the API.

I'm going to assume that you've successfully registered for a [free **moltin** account][3], and [authenticated][4] with v1.* of the API using your Client ID and Client Secret to obtain a valid Access Token - its use here is indicated by `$ACCESS_TOKEN` and can be replaced by your own valid Access Token.

Before we get started, we'll perform a quick to check to ensure we're correctly authenticated against Moltin's API by attempting to retrieve our account information:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" https://api.molt.in/v1/account | jq
{% endhighlight %}

All being well we should see some account information and we can successfully carry on.

We'll start by creating a product to assign modifiers and variants to, but before we can do that the [documentation][5] states that we're going to need the ID of a category and a tax band to assign to the product on creation.

Let's see what categories we have in our store:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" https://api.molt.in/v1/categories | jq
{% endhighlight %}

As you can see, Moltin has already created a default category for us when we registered. You're free to create your own categories too, so if you'd like to do so head on over to [the documentation][6] to see how that's done. We're going to need some tax band information too, so let's see what's available:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" https://api.molt.in/v1/taxes | jq
{% endhighlight %}

It seems Moltin have created a default tax band for us too, we now we have the ID of a category and the ID of a tax band available for use to assign to a new product.

Let's add a Standard T-Shirt to our store:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "sku=SKU001" \
    --data-urlencode "title=Standard T-Shirt" \
    --data-urlencode "slug=standard-t-shirt" \
    --data-urlencode "price=1.99" \
    --data-urlencode "status=1" \
    --data-urlencode "category=1089727883485643201" \
    --data-urlencode "stock_level=100" \
    --data-urlencode "stock_status=1" \
    --data-urlencode "tax_band=1089727883636638001" \
    --data-urlencode "catalog_only=0" \
    --data-urlencode "requires_shipping=1" \
    --data-urlencode "description=Standard T-Shirt" \
    https://api.molt.in/v1/products | jq
{% endhighlight %}

Our Standard T-Shirt is going to cost 1.99, carry the SKU001 SKU, and belong to the default category and default tax band. Now that we've created our very first product, let's make sure it's ready to use:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" https://api.molt.in/v1/products | jq
{% endhighlight %}

Our Standard T-Shirt is going to come in three different sizes "Small", "Medium", and "Large". When we sell our Standard T-Shirt we'd like to charge an additional 0.50 for "Medium" and an additional 1.00 for "Large". So to do that, we're going to create a variant modifier to hold these options for us:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "title=Size" \
    --data-urlencode "type=variant" \
    --data-urlencode "instructions=Size options for our Standard T-Shirt" \
    https://api.molt.in/v1/products/1154603472042066112/modifiers | jq
{% endhighlight %}

With the modifier created, we can use the returned modifier ID to add our "Small", "Medium", and "Large" variant options:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "title=Small" \
    https://api.molt.in/v1/products/1154603472042066112/modifiers/1154604576049987777/variations | jq

curl -sH "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "title=Medium" \
    --data-urlencode "mod_price=+0.50" \
    https://api.molt.in/v1/products/1154603472042066112/modifiers/1154604576049987777/variations | jq

curl -sH "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "title=Large" \
    --data-urlencode "mod_price=+1.00" \
    https://api.molt.in/v1/products/1154603472042066112/modifiers/1154604576049987777/variations | jq
{% endhighlight %}

We've only used the `mod_price` parameter for the "Medium" and "Large" options as those are the only options where we want the price to change when purchased. The `mod_price` parameter accepts a decimal prefixed with `+`, `-` or `=` (eg. +0.50, -1.50, =5.99).

When we view our product we should see the newly created modifiers and variants:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" https://api.molt.in/v1/products/1154603472042066112 | jq
{% endhighlight %}

Success!

We'll now move on to adding a product variant to a cart (or basket). A cart is created automatically for you when adding a product to one, the id of which is user defined, so you do not need to create a cart resource to add a product to. In this instance I've defined the name of my cart as `my-demo-cart`. It's worth noting that you've created a product with variations you cannot add the parent product to a cart, with that in mind let's add a "Medium" Standard T-Shirt to a cart:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "id=1154603472042066112" \
    --data-urlencode "modifier[1154604576049987777]=1154605147146420420" \
    --data-urlencode "quantity=1" \
    https://api.molt.in/v1/carts/my-demo-cart | jq
{% endhighlight %}

We pass a `modifier` parameter along with the product ID and quantity to indicate to the API that this is a variant of our Standard T-Shirt. The `modifier` parameter is an Array containing the ID of the modifier as the key and the variant ID and the value - this allows you to combine multiple modifiers and variants such as "Medium" and "Red".

Now let's add a "Large" one too, just in case we've put on a little Christmas Weight™ over the holidays:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "id=1154603472042066112" \
    --data-urlencode "modifier[1154604576049987777]=1154605210790789318" \
    --data-urlencode "quantity=1" \
    https://api.molt.in/v1/carts/my-demo-cart | jq
{% endhighlight %}

Let's see what our cart now contains:-

{% highlight bash %}
curl -sH "Authorization: Bearer $ACCESS_TOKEN" https://api.molt.in/v1/carts/my-demo-cart | jq
{% endhighlight %}

There you have it! We've created a product, defined a modifier for the product and it's variants, and added it to a cart ready for checkout - a whistle stop tour of Moltin's Product Modifiers and Variants.

[1]: https://stedolan.github.io/jq/
[2]: http://curl.haxx.se/
[3]: https://moltin.com/register
[4]: http://docs.moltin.com/api/1.0/authentication
[5]: http://docs.moltin.com/api/1.0/product/php#post-product
[6]: http://docs.moltin.com/api/1.0/category/php#create-category
