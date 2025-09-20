import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../enums.dart'; // Importando as definições compartilhadas

class SidebarMenu extends StatefulWidget {
  final MenuItem selectedMenu;
  final SubItem? selectedSubItem;
  final Function(MenuItem, {SubItem? subItem}) onMenuItemSelected;

  const SidebarMenu({
    Key? key,
    required this.selectedMenu,
    required this.selectedSubItem,
    required this.onMenuItemSelected,
  }) : super(key: key);

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;
  MenuItem? _expandedMenu;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = _isCollapsed ? 70 : 250;
    final primaryColor = const Color(0xFFF28C38);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 8 : 16,
              vertical: 16,
            ),
            child: SizedBox(
              height: 100,
              child: Image.network(
                'https://aogosto.com.br/delivery/wp-content/uploads/2025/03/go-laranja-maior-1.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            menuItem: MenuItem.dashboard,
            hasSubmenu: false,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 8),
          _buildMenuItem(
            icon: Icons.list_alt,
            label: 'Pedidos',
            menuItem: MenuItem.pedidos,
            hasSubmenu: true,
            subItems: [
              {'label': 'Criar Pedido', 'subItem': PedidosSubItem.criarPedido, 'icon': Icons.add},
              {'label': 'Ver Pedidos', 'subItem': PedidosSubItem.verPedidos, 'icon': Icons.visibility},
            ],
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 8),
          _buildMenuItem(
            icon: Icons.payment,
            label: 'Pagamentos',
            menuItem: MenuItem.pagamentos,
            hasSubmenu: true,
            subItems: [
              {'label': 'Criar Link', 'subItem': PagamentosSubItem.criarLink, 'icon': Icons.link},
              {'label': 'Conferir Pagamentos', 'subItem': PagamentosSubItem.conferirPagamentos, 'icon': Icons.receipt},
            ],
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 8),
          _buildMenuItem(
            icon: Icons.store,
            label: 'Unidades',
            menuItem: MenuItem.unidades,
            hasSubmenu: false,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 8),
          _buildMenuItem(
            icon: Icons.support_agent,
            label: 'Suporte',
            menuItem: MenuItem.suporte,
            hasSubmenu: false,
            primaryColor: primaryColor,
          ),
          const Spacer(),
          const SizedBox(height: 16),
          _buildCollapseButton(primaryColor),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required MenuItem menuItem,
    required bool hasSubmenu,
    List<Map<String, dynamic>>? subItems,
    required Color primaryColor,
  }) {
    final bool isSelected = widget.selectedMenu == menuItem;
    final bool isExpanded = _expandedMenu == menuItem;
    double scale = 1.0;

    return Column(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: StatefulBuilder(
            builder: (context, setState) {
              return GestureDetector(
                onTapDown: (_) => setState(() => scale = 0.95),
                onTapUp: (_) => setState(() => scale = 1.0),
                onTap: () {
                  setState(() {
                    if (hasSubmenu) {
                      if (isExpanded) {
                        _expandedMenu = null;
                        _controller.reverse();
                      } else {
                        _expandedMenu = menuItem;
                        _controller.forward();
                      }
                      // Chama o callback para selecionar o item principal
                      widget.onMenuItemSelected(menuItem);
                    } else {
                      _expandedMenu = null;
                      widget.onMenuItemSelected(menuItem);
                    }
                  });
                },
                child: AnimatedScale(
                  scale: scale,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? primaryColor.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (hasSubmenu)
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (hasSubmenu && isExpanded && !_isCollapsed)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(left: 16, right: 8, top: 4),
            child: Column(
              children: subItems!.asMap().entries.map((entry) {
                int index = entry.key;
                var subItem = entry.value;
                final bool isSubSelected = widget.selectedSubItem == subItem['subItem'];
                return AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - _fadeAnimation.value) * 20 * (index + 1)),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: InkWell(
                    onTap: () {
                      widget.onMenuItemSelected(menuItem, subItem: subItem['subItem']);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSubSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: isSubSelected ? primaryColor.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            subItem['icon'] as IconData?,
                            size: 18,
                            color: isSubSelected
                                ? primaryColor
                                : Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subItem['label'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: isSubSelected
                                    ? primaryColor
                                    : Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isSubSelected)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCollapseButton(Color primaryColor) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Center(
              child: Icon(
                _isCollapsed ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                size: 18,
                color: primaryColor,
              ),
            ),
            onPressed: () {
              setState(() {
                _isCollapsed = !_isCollapsed;
                if (_isCollapsed) {
                  _expandedMenu = null;
                  _controller.reverse();
                }
              });
            },
            tooltip: _isCollapsed ? 'Expandir Menu' : 'Recolher Menu',
          ),
        ),
      ),
    );
  }
}