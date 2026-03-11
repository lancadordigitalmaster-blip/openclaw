#!/usr/bin/env python3
"""
Generate PDF report for Wolf Agency designer workload.
Usage: python generate_designer_report.py --date 2026-03-04 --output report.pdf
"""

import argparse
import json
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.pdfgen import canvas

def create_header(canvas, doc):
    """Draw header on each page."""
    canvas.saveState()
    
    # Background
    canvas.setFillColor(colors.HexColor('#181D21'))
    canvas.rect(0, doc.height + doc.topMargin - 60, doc.width + doc.leftMargin + doc.rightMargin, 80, fill=1, stroke=0)
    
    # Logo and title
    canvas.setFillColor(colors.white)
    canvas.setFont('Helvetica-Bold', 24)
    canvas.drawString(doc.leftMargin, doc.height + doc.topMargin - 35, '🐺 WOLF AGENCY')
    
    canvas.setFont('Helvetica', 10)
    canvas.setFillColor(colors.HexColor('#888888'))
    canvas.drawString(doc.leftMargin, doc.height + doc.topMargin - 50, 'Relatório Operacional de Design')
    
    # Date
    canvas.setFillColor(colors.white)
    canvas.setFont('Helvetica', 9)
    canvas.drawRightString(doc.width + doc.leftMargin, doc.height + doc.topMargin - 35, datetime.now().strftime('%d/%m/%Y'))
    canvas.drawRightString(doc.width + doc.leftMargin, doc.height + doc.topMargin - 48, datetime.now().strftime('%H:%M BRT'))
    
    canvas.restoreState()

def generate_report(date_str, output_path):
    """Generate PDF report."""
    
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=20*mm,
        leftMargin=20*mm,
        topMargin=30*mm,
        bottomMargin=20*mm
    )
    
    styles = getSampleStyleSheet()
    story = []
    
    # Title
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=20,
        textColor=colors.HexColor('#1a1a1a'),
        spaceAfter=20,
        alignment=TA_LEFT
    )
    
    story.append(Paragraph(f'Relatório do Dia — {date_str}', title_style))
    story.append(Spacer(1, 20))
    
    # Designer data (mock - replace with actual ClickUp API call)
    designers = [
        {'name': 'Pedro', 'current': 13, 'meta': 17, 'status': 'danger'},
        {'name': 'Leoneli', 'current': 6, 'meta': 12, 'status': 'ok'},
        {'name': 'Eliedson', 'current': 5, 'meta': 8, 'status': 'ok'},
        {'name': 'Abílio', 'current': 8, 'meta': 14, 'status': 'ok'},
        {'name': 'Levi', 'current': 1, 'meta': 2, 'status': 'ok'},
        {'name': 'Rodrigo', 'current': 0, 'meta': 0, 'status': 'warning'},
    ]
    
    # Designers table
    table_data = [['Designer', 'Atual', 'Meta', 'Status', '%']]
    
    for d in designers:
        pct = (d['current'] / d['meta'] * 100) if d['meta'] > 0 else 0
        status_color = {
            'ok': '✅ OK',
            'warning': '⚠️ Atenção', 
            'danger': '🔴 Crítico'
        }.get(d['status'], '-')
        
        table_data.append([
            d['name'],
            str(d['current']),
            str(d['meta']),
            status_color,
            f'{pct:.0f}%'
        ])
    
    table = Table(table_data, colWidths=[80*mm, 25*mm, 25*mm, 35*mm, 20*mm])
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1a1a1a')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 10),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor('#f5f5f5')),
        ('GRID', (0, 0), (-1, -1), 1, colors.HexColor('#ddd')),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 9),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#fafafa')]),
    ]))
    
    story.append(table)
    story.append(Spacer(1, 30))
    
    # Alerts section
    alert_style = ParagraphStyle(
        'Alert',
        parent=styles['Normal'],
        fontSize=10,
        textColor=colors.HexColor('#c33'),
        spaceAfter=10,
        leftIndent=10,
        borderWidth=1,
        borderColor=colors.HexColor('#fcc'),
        borderPadding=10,
        backColor=colors.HexColor('#fee')
    )
    
    story.append(Paragraph('🔴 ALERTAS', styles['Heading2']))
    story.append(Spacer(1, 10))
    story.append(Paragraph('• Pedro: 13/17 demandas (faltam 4 para meta)', alert_style))
    story.append(Paragraph('• Karen: 5 tarefas em alteração (retrabalho)', alert_style))
    story.append(Paragraph('• 3 tarefas sem data de vencimento', alert_style))
    
    # Build PDF
    doc.build(story, onFirstPage=create_header, onLaterPages=create_header)
    print(f'✅ Report generated: {output_path}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate Wolf Agency designer report')
    parser.add_argument('--date', required=True, help='Report date (YYYY-MM-DD)')
    parser.add_argument('--output', required=True, help='Output PDF path')
    
    args = parser.parse_args()
    generate_report(args.date, args.output)
