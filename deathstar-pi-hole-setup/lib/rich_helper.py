#!/usr/bin/env python3
#===============================================================================
# File: rich_helper.py
# Project: Death Star Pi-hole Setup
# Description: Rich terminal output helper for Death Star Pi scripts
#              Provides enhanced visual formatting using the Rich library
#              for improved user experience with colors, panels, and progress bars.
# 
# Target Environment:
#   OS: Raspberry Pi OS aarch64
#   Host: Raspberry Pi 5 Model B Rev 1.1
#   Python: 3.x
#   Dependencies: rich
# 
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#===============================================================================

import argparse
import time
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeRemainingColumn
from rich.text import Text
from rich.align import Align
from rich import box

console = Console()

#===============================================================================
# Function: print_header
# Description: Print a fancy header with optional subtitle
# Parameters:
#   title - Main header title
#   subtitle - Optional subtitle (default: "")
# Returns: None
#===============================================================================
def print_header(title, subtitle=""):
    """Print a fancy header"""
    header_text = Text(title, style="bold blue")
    if subtitle:
        header_text.append(f"\n{subtitle}", style="dim")
    
    panel = Panel(
        Align.center(header_text),
        box=box.DOUBLE,
        border_style="blue",
        padding=(1, 2)
    )
    console.print(panel)

def print_section(title):
    """Print a section header"""
    console.print(f"\n[bold cyan]═══ {title} ═══[/bold cyan]")

def print_status(message, style="info"):
    """Print a status message with appropriate styling"""
    styles = {
        "info": "blue",
        "success": "green", 
        "warning": "yellow",
        "error": "red"
    }
    console.print(f"[{styles.get(style, 'white')}]{message}[/{styles.get(style, 'white')}]")

def print_check(name, status, details=""):
    """Print a check result with status"""
    status_icons = {
        "PASS": "✅",
        "FAIL": "❌", 
        "WARN": "⚠️",
        "INFO": "ℹ️"
    }
    
    status_colors = {
        "PASS": "green",
        "FAIL": "red",
        "WARN": "yellow", 
        "INFO": "blue"
    }
    
    icon = status_icons.get(status, "•")
    color = status_colors.get(status, "white")
    
    console.print(f"  {icon} [{color}]{status}[/{color}] - {name}")
    if details:
        console.print(f"       {details}")

def print_table(headers, rows, title=""):
    """Print a formatted table"""
    table = Table(title=title, box=box.ROUNDED)
    
    for header in headers:
        table.add_column(header, style="cyan", no_wrap=True)
    
    for row in rows:
        table.add_row(*row)
    
    console.print(table)

def print_progress_bar(description):
    """Show a progress bar"""
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        TimeRemainingColumn(),
    ) as progress:
        task = progress.add_task(description, total=100)
        
        for i in range(100):
            time.sleep(0.02)  # Simulate work
            progress.update(task, advance=1)

def print_summary(total, passed, warnings, failed, rate=None, overall_status=None):
    """Print a summary with statistics"""
    if rate is None:
        success_rate = round((passed / total) * 100) if total > 0 else 0
    else:
        success_rate = rate
    
    # Create summary table
    table = Table(title="📊 Summary Statistics", box=box.ROUNDED)
    table.add_column("Metric", style="cyan", no_wrap=True)
    table.add_column("Count", style="white", no_wrap=True)
    
    table.add_row("Total Categories", str(total))
    table.add_row("✅ Passed", f"[green]{passed}[/green]")
    table.add_row("⚠️  Warnings", f"[yellow]{warnings}[/yellow]")
    table.add_row("❌ Failed", f"[red]{failed}[/red]")
    table.add_row("📈 Success Rate", f"[bold]{success_rate}%[/bold]")
    
    console.print(table)
    
    # Overall status
    if overall_status:
        if overall_status == "EXCELLENT":
            status_panel = Panel(
                "[bold green]🌟 EXCELLENT[/bold green]\n[dim]All critical checks passed! Scripts are well-synchronized.[/dim]",
                border_style="green",
                box=box.ROUNDED
            )
        elif overall_status == "GOOD":
            status_panel = Panel(
                "[bold yellow]⚠️  GOOD[/bold yellow]\n[dim]Minor issues detected. Review failed checks below.[/dim]",
                border_style="yellow",
                box=box.ROUNDED
            )
        else:  # NEEDS ATTENTION
            status_panel = Panel(
                "[bold red]❌ NEEDS ATTENTION[/bold red]\n[dim]Multiple issues detected. Immediate review recommended.[/dim]",
                border_style="red",
                box=box.ROUNDED
            )
        console.print(status_panel)
    else:
        # Auto-determine status
        if failed == 0 and warnings == 0:
            status_panel = Panel(
                "[bold green]🌟 EXCELLENT[/bold green]\n[dim]All critical checks passed! Scripts are well-synchronized.[/dim]",
                border_style="green",
                box=box.ROUNDED
            )
        elif failed <= 3:
            status_panel = Panel(
                "[bold yellow]⚠️  GOOD[/bold yellow]\n[dim]Minor issues detected. Review failed checks below.[/dim]",
                border_style="yellow",
                box=box.ROUNDED
            )
        else:
            status_panel = Panel(
                "[bold red]❌ NEEDS ATTENTION[/bold red]\n[dim]Multiple issues detected. Immediate review recommended.[/dim]",
                border_style="red",
                box=box.ROUNDED
            )
        console.print(status_panel)

def print_disclaimer(disclaimer_type="legal"):
    """Print a disclaimer box"""
    if disclaimer_type == "legal":
        content = """[bold red]⚠️  LEGAL DISCLAIMER ⚠️[/bold red]

This script is provided 'AS IS' without warranty of any kind.
The author(s) cannot be held responsible for any damage,
data loss, system instability, or other issues that may
result from running this script.

[bold]YOU RUN THIS SCRIPT ENTIRELY AT YOUR OWN RISK.[/bold]

By proceeding, you acknowledge that you:
• Understand the risks involved
• Have backups of important data
• Accept full responsibility for any consequences
• Release the author(s) from any liability"""
        
        panel = Panel(
            content,
            title="[bold red]LEGAL DISCLAIMER[/bold red]",
            border_style="red",
            box=box.DOUBLE,
            padding=(1, 2)
        )
    elif disclaimer_type == "removal":
        content = """[bold red]🚨 COMPLETE REMOVAL CONFIRMATION 🚨[/bold red]

This will [bold]COMPLETELY REMOVE[/bold] all Death Star Pi components:
• Docker and all containers
• Ansible (if installed by this script)
• All configuration files and data
• System modifications and optimizations

Type '[bold yellow]REMOVE DEATH STAR[/bold yellow]' to proceed with complete removal,
or anything else to use interactive mode."""
        
        panel = Panel(
            content,
            title="[bold red]COMPLETE REMOVAL CONFIRMATION[/bold red]",
            border_style="red",
            box=box.DOUBLE,
            padding=(1, 2)
        )
    elif disclaimer_type == "system_removal":
        content = """[bold red]⚠️  COMPLETE SYSTEM REMOVAL ⚠️[/bold red]

This will completely remove all Death Star Pi components:
• Pi-hole (DNS filtering)
• Grafana & Prometheus (monitoring)
• All monitoring services
• Docker containers, images, and volumes
• internet-pi repository and configurations
• Ansible collections and configurations
• System hostname and /etc/hosts changes
• Pi 5 boot optimizations (if applicable)
• PADD alias and customizations (if applicable)

[bold red]⚠️  THIS ACTION CANNOT BE UNDONE! ⚠️[/bold red]"""
        
        panel = Panel(
            content,
            title="[bold red]COMPLETE SYSTEM REMOVAL[/bold red]",
            border_style="red",
            box=box.DOUBLE,
            padding=(1, 2)
        )
    else:
        # Default panel if unknown type
        panel = Panel(
            "[bold yellow]Unknown disclaimer type[/bold yellow]",
            border_style="yellow",
            box=box.ROUNDED
        )
    
    console.print(panel)

def main():
    parser = argparse.ArgumentParser(description="Rich terminal output helper")
    parser.add_argument("command", choices=[
        "header", "section", "status", "check", "table", "summary", "progress", "disclaimer"
    ])
    parser.add_argument("--title", help="Title text")
    parser.add_argument("--subtitle", help="Subtitle text")
    parser.add_argument("--message", help="Message text")
    parser.add_argument("--style", help="Style (info, success, warning, error)")
    parser.add_argument("--type", help="Type (legal, removal, system_removal)")
    parser.add_argument("--name", help="Check name")
    parser.add_argument("--status", help="Status (PASS, FAIL, WARN, INFO)")
    parser.add_argument("--details", help="Additional details")
    parser.add_argument("--total", type=int, help="Total count")
    parser.add_argument("--passed", type=int, help="Passed count")
    parser.add_argument("--warnings", type=int, help="Warning count") 
    parser.add_argument("--failed", type=int, help="Failed count")
    parser.add_argument("--rate", type=int, help="Success rate percentage")
    parser.add_argument("--overall-status", help="Overall status (EXCELLENT, GOOD, NEEDS ATTENTION)")
    
    args = parser.parse_args()
    
    if args.command == "header":
        print_header(args.title or "Header", args.subtitle or "")
    elif args.command == "section":
        print_section(args.title or "Section")
    elif args.command == "status":
        print_status(args.message or "Status", args.style or "info")
    elif args.command == "check":
        print_check(args.name or "Check", args.status or "PASS", args.details or "")
    elif args.command == "disclaimer":
        print_disclaimer(args.type or "legal")
    elif args.command == "summary":
        print_summary(
            args.total or 0,
            args.passed or 0, 
            args.warnings or 0,
            args.failed or 0,
            args.rate,
            getattr(args, 'overall_status', None)
        )
    elif args.command == "progress":
        print_progress_bar(args.message or "Processing")

if __name__ == "__main__":
    main()