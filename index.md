---
layout: default
---

<ul>
	{% for post in site.posts %}
	<li>
		<h3><a href="{{ post.url }}">{{ post.title }}</a></h3>
		<h5>{{ post.date | date: "%-d %B %Y" }}</h5>
		{{ post.excerpt }}
		<a href="{{ post.url }}">Continue reading...</a>
	</li>
	<br/>
	{% endfor %}
</ul>
