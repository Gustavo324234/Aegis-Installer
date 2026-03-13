# TAREA: CORRECCIÓN DE BANNER ASCII Y FORMATO [INST-107]

## 📋 Descripción
El banner ASCII en el instalador presentaba una errata visual y problemas de renderizado en terminales de ancho variable. Se requiere corregir el arte ASCII para que rece "AEGIS OS" y asegurar su estabilidad en diferentes tamaños de TTY.

## 🎯 Objetivos
1.  **Corrección del Typos**: Cambiar el arte ASCII para que represente correctamente "AEGIS OS".
2.  **Resiliencia de Renderizado**: Formatear el bloque ASCII para un ancho seguro (40-60 caracteres) y eliminar espacios innecesarios al inicio de línea.
3.  **Consistencia**: Asegurar que el banner sea el primer elemento visual tras limpiar la pantalla.

## ✅ Criterios de Aceptación
- [ ] El banner muestra claramente "AEGIS OS".
- [ ] No hay caracteres de escape rotos ni alineaciones incorrectas.
- [ ] El script se ejecuta correctamente en terminales de 80 columnas.
- [ ] Mensaje de commit sigue el estándar: `style(installer): fix ASCII banner typo and formatting [INST-107]`.
