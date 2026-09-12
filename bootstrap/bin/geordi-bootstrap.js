#!/usr/bin/env node
import { runCli } from '../src/cli.js'
try { process.exitCode = await runCli(process.argv.slice(2)) }
catch (error) { console.error(`Error: ${error.message}`); process.exitCode = 2 }
