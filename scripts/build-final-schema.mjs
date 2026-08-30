import { readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const migrationsDir = join(root, "supabase", "migrations");
const output = join(root, "supabase", "eco_healthy_schema_final.sql");
const files = (await readdir(migrationsDir)).filter((name) => name.endsWith(".sql")).sort();
const sections = [];
for (const file of files) sections.push(`-- ============================================================\n-- ${file}\n-- ============================================================\n${(await readFile(join(migrationsDir, file), "utf8")).trim()}\n`);
await writeFile(output, `-- ECO Healthy ERP — Final integrated Supabase schema\n-- Generated from ordered, rerunnable migrations. Demo data is installed only by the explicit admin command.\n\n${sections.join("\n")}`);
console.log(`Built ${output} from ${files.length} migrations.`);
