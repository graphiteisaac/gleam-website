import gleam/list
import gleam/option
import gleam/set
import gleam/string
import lustre/attribute.{class} as attr
import lustre/element/html
import website/fs
import website/site.{PageMeta}

pub type Guide {
  Guide(tags: List(String), title: String, path: String, target: Target)
}

pub type Target {
  Any
  Erlang
  Javascript
}

pub fn target_string(target: Target) -> String {
  case target {
    Javascript -> "JavaScript"
    Erlang -> "Erlang"
    Any -> "Any"
  }
}

// TODO: Consider parsing these directly from frontmatter in the 
// pages/documentation directory. It would require a bit of a rethink
// of how page loading currently works, though.
const guides = [
  Guide(
    title: "Using the Gleam build tool",
    target: Any,
    tags: ["basic"],
    path: "/writing-gleam",
  ),
  Guide(
    title: "Conventions, patterns and anti-patterns",
    target: Any,
    tags: ["basic", "patterns"],
    path: "/documentation/conventions-patterns-and-anti-patterns",
  ),
  Guide(
    title: "Using external functions",
    target: Any,
    tags: ["basic", "ffi"],
    path: "/documentation/externals",
  ),
]

pub fn index(ctx: site.Context) -> fs.File {
  let meta =
    PageMeta(
      path: "guides",
      title: "Guides",
      subtitle: "From a first time user to a Gleam veteran, learn from our guides!",
      meta_title: "TODO",
      description: "TODO",
      preview_image: option.None,
    )

  let guide_icon = fn(target: Target) {
    html.img([
      attr.src(
        "/images/target-"
        <> case target {
          Any -> "any"
          Erlang -> "erlang"
          Javascript -> "javascript"
        }
        <> "-icon.svg",
      ),
    ])
  }

  let #(tags, guides) =
    list.fold(guides, #(set.new(), []), fn(acc, guide) {
      let #(tags, guides) = acc
      let tags =
        list.fold(guide.tags, tags, fn(tag_acc, tag) {
          set.insert(tag_acc, tag)
        })

      #(tags, [
        html.li([], [
          html.a([class("link"), attr.href(guide.path)], [
            html.h4([], [html.text(guide.title)]),
            html.ul([class("link-meta")], [
              html.li([class("guide-target")], [
                guide_icon(guide.target),
                html.text(target_string(guide.target)),
              ]),
              html.li([class("guide-tags")], [
                html.img([
                  attr.src("/images/tag-icon.svg"),
                  attr.alt("Tag icon"),
                ]),
                html.text(
                  guide.tags
                  |> string.join(", "),
                ),
              ]),
            ]),
          ]),
        ]),
        ..guides
      ])
    })

  let tags = set.to_list(tags)

  [
    html.h5([class("guide-filter-label")], [html.text("Filter by tag")]),
    html.ul(
      [class("tag-picker")],
      list.map(tags, fn(tag) {
        html.li([], [html.button([], [html.text(tag)])])
      }),
    ),
    html.h5([class("guide-filter-label")], [html.text("Or search by title")]),
    html.form([class("guide-search-form")], [
      html.input([
        attr.type_("text"),
        attr.placeholder("eg. external, patterns, http"),
      ]),
      html.img([
        class("search-icon"),
        attr.src("/images/search-icon.svg"),
        attr.alt("Search icon"),
        attr.aria_hidden(True),
      ]),
    ]),
    html.ul([class("link-cards guides-list")], guides),
    html.script([], filter_script),
  ]
  |> site.page_layout("", meta, ctx)
  |> site.to_html_file(meta)
}

const filter_script = "
function updateDisplayedGuides(tags, filterValue) {
	const search = filterValue.trim().toLowerCase();

	for (const guide of document.querySelectorAll(\".link-cards>li\")) {
		const tagsEl = guide.querySelector(\".guide-tags\");
		const guideTags = tagsEl ? tagsEl.textContent : \"\";

		// Guide must include every active tag
		const matchesTags = tags.every((tag) => guideTags.includes(tag));

		// Guide must match the search string somewhere in its text
		const matchesSearch =
			search.length === 0 || guide.textContent.toLowerCase().includes(search);

		guide.style.display = matchesTags && matchesSearch ? \"\" : \"none\";
	}

  if ([...document.querySelectorAll(\".link-cards>li\")].every(child => window.getComputedStyle(child).display === 'none'))
    document.querySelector('.guides-list').classList.add('empty')
  else
    document.querySelector('.guides-list').classList.remove('empty')
}

const filter = new Proxy(
	{ value: \"\" },
	{
		set(target, prop, value) {
			target[prop] = value;
			updateDisplayedGuides(tags, filter.value);
			return true;
		},
	},
);

const tags = new Proxy([], {
	set(target, prop, value) {
		target[prop] = value;
		updateDisplayedGuides(tags, filter.value);
		return true;
	},
});

for (const button of document.querySelectorAll(\".tag-picker button\")) {
	const tag = button.textContent;
	button.addEventListener(\"click\", () => {
		if (tags.includes(tag)) {
			tags.splice(tags.indexOf(tag), 1);
			button.classList.remove(\"active\");
			return;
		}
		tags.push(tag);
		button.classList.add(\"active\");
	});
}

const searchInput = document.querySelector(\".guide-search-form input\");

searchInput.addEventListener(\"input\", () => {
	filter.value = searchInput.value;
});
"
