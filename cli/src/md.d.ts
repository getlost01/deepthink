// Markdown files imported as text (Bun `with { type: "text" }`) — embedded at compile time.
declare module "*.md" {
  const content: string;
  export default content;
}
