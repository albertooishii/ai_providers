#!/bin/bash

# Script para instalar hooks de Git para ai_providers
# Ejecuta: chmod +x scripts/install-hooks.sh && ./scripts/install-hooks.sh

echo "🔧 Instalando hooks de Git para ai_providers..."

# Crear el directorio de hooks si no existe
mkdir -p .git/hooks

# Crear el hook pre-commit
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Pre-commit hook para ai_providers
# Ejecuta dart fix --apply, dart format y dart doc antes de cada commit

set -e  # Salir si algún comando falla

echo "🔧 Pre-commit hook: Ejecutando dart fix --apply..."

# Ejecutar dart fix --apply
if ! dart fix --apply; then
    echo "❌ Error: dart fix --apply falló"
    exit 1
fi

echo "✅ dart fix --apply completado"

echo "🎨 Pre-commit hook: Ejecutando dart format..."

# Ejecutar dart format en todos los archivos .dart
if ! dart format --set-exit-if-changed .; then
    echo "⚠️  Algunos archivos fueron formateados automáticamente"
    echo "🔄 Añadiendo archivos formateados al commit..."
    
    # Añadir automáticamente los archivos formateados
    git add .
    
    echo "✅ Archivos formateados añadidos automáticamente al commit"
else
    echo "✅ dart format completado - no se necesitaron cambios"
fi

echo "📚 Pre-commit hook: Generando documentación..."

# Ejecutar dart doc para generar documentación actualizada
if ! dart doc; then
    echo "❌ Error: dart doc falló"
    exit 1
fi

echo "✅ dart doc completado - documentación actualizada (no se añade al commit, se genera automáticamente en pub.dev)"

echo "🚀 Pre-commit hook completado exitosamente!"
EOF

# Hacer el hook ejecutable
chmod +x .git/hooks/pre-commit

echo "✅ Hook pre-commit instalado exitosamente!"
echo ""
echo "📋 El hook ejecutará automáticamente en cada commit:"
echo "   - dart fix --apply"
echo "   - dart format"
echo "   - dart doc"
echo "   - Añadirá cambios automáticamente"
echo ""
echo "🎯 Para desinstalar: rm .git/hooks/pre-commit"