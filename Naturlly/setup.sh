#!/bin/bash

# Script para abrir Xcode y mostrar instrucciones
echo "========================================="
echo "  Naturlly TTS - Setup Automático"
echo "========================================="
echo ""
echo "Este script abrirá Xcode para crear el proyecto."
echo ""
echo "INSTRUCCIONES:"
echo ""
echo "1. En Xcode, selecciona: File → New → Project"
echo "2. Elige: iOS → App"
echo "3. Configura:"
echo "   - Product Name: Naturlly"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "4. Guarda en: /Users/mike/Downloads/"
echo "5. Luego ejecuta: ./add_files.sh"
echo ""
echo "¿Quieres abrir Xcode ahora? (y/n)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    open -a Xcode
    echo ""
    echo "✅ Xcode abierto. Sigue las instrucciones arriba."
    echo "   Cuando termines, ejecuta: ./add_files.sh"
else
    echo "❌ Cancelado. Cuando estés listo, ejecuta: ./setup.sh"
fi
