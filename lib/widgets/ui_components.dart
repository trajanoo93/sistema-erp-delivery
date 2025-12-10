import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 Componentes UI Otimizados - Sistema de Pedidos
/// Design refinado com micro-animações e feedback visual aprimorado

// ============================================================================
// 🟢 STATUS BADGE - Mostra status do pedido nas tabs
// ============================================================================

enum PedidoStatus {
  empty,       // 🔴 Pedido vazio
  incomplete,  // 🟡 Incompleto (faltam dados)
  complete,    // 🟢 Completo (pronto para enviar)
  processing,  // ⏳ Processando
}

class StatusBadge extends StatelessWidget {
  final PedidoStatus status;
  final double size;

  const StatusBadge({
    Key? key,
    required this.status,
    this.size = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: config.backgroundColor.withOpacity(0.2),
            ),
            child: Icon(
              config.icon,
              size: size,
              color: config.color,
            ),
          ),
        );
      },
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case PedidoStatus.empty:
        return _StatusConfig(
          icon: Icons.radio_button_unchecked,
          color: Colors.grey.shade400,
          backgroundColor: Colors.grey.shade100,
        );
      case PedidoStatus.incomplete:
        return _StatusConfig(
          icon: Icons.warning_rounded,
          color: Colors.orange.shade600,
          backgroundColor: Colors.orange.shade50,
        );
      case PedidoStatus.complete:
        return _StatusConfig(
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade600,
          backgroundColor: Colors.green.shade50,
        );
      case PedidoStatus.processing:
        return _StatusConfig(
          icon: Icons.sync_rounded,
          color: Colors.blue.shade600,
          backgroundColor: Colors.blue.shade50,
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  _StatusConfig({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

// ============================================================================
// 📊 PROGRESS BAR - Mostra % de completude do pedido
// ============================================================================

class PedidoProgressBar extends StatelessWidget {
  final double progress; // 0.0 a 1.0
  final Color? color;

  const PedidoProgressBar({
    Key? key,
    required this.progress,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? const Color(0xFFF28C38);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Completude do Pedido',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: progress),
          builder: (context, value, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: isDarkMode 
                    ? Colors.grey.shade800 
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// 💙 MANUAL EDIT INDICATOR - Mostra quando frete foi editado manualmente
// ============================================================================

class ManualEditIndicator extends StatelessWidget {
  final bool isManuallyEdited;
  final VoidCallback? onReset;

  const ManualEditIndicator({
    Key? key,
    required this.isManuallyEdited,
    this.onReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isManuallyEdited) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.blue.shade100.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Taxa de frete editada manualmente',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                if (onReset != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onReset,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// ⏳ LOADING STATE - Estados de loading específicos
// ============================================================================

enum LoadingType {
  fetchingCep,
  calculatingShipping,
  fetchingCustomer,
  creatingOrder,
  validatingCoupon,
}

class SpecificLoadingIndicator extends StatelessWidget {
  final LoadingType type;
  final Color? color;

  const SpecificLoadingIndicator({
    Key? key,
    required this.type,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? const Color(0xFFF28C38);
    final config = _getLoadingConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                config.title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              if (config.subtitle != null)
                Text(
                  config.subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: primaryColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  _LoadingConfig _getLoadingConfig() {
    switch (type) {
      case LoadingType.fetchingCep:
        return _LoadingConfig(
          title: 'Buscando endereço...',
          subtitle: 'Consultando CEP',
        );
      case LoadingType.calculatingShipping:
        return _LoadingConfig(
          title: 'Calculando frete...',
          subtitle: 'Verificando melhor opção',
        );
      case LoadingType.fetchingCustomer:
        return _LoadingConfig(
          title: 'Buscando cliente...',
          subtitle: 'Carregando dados',
        );
      case LoadingType.creatingOrder:
        return _LoadingConfig(
          title: 'Criando pedido...',
          subtitle: 'Processando pagamento',
        );
      case LoadingType.validatingCoupon:
        return _LoadingConfig(
          title: 'Validando cupom...',
          subtitle: null,
        );
    }
  }
}

class _LoadingConfig {
  final String title;
  final String? subtitle;

  _LoadingConfig({
    required this.title,
    this.subtitle,
  });
}

// ============================================================================
// ℹ️ INFO TOOLTIP - Tooltips informativos
// ============================================================================

class InfoTooltip extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;

  const InfoTooltip({
    Key? key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? const Color(0xFFF28C38);

    return Tooltip(
      message: message,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      preferBelow: false,
      child: Icon(
        icon,
        size: 18,
        color: primaryColor.withOpacity(0.6),
      ),
    );
  }
}

// ============================================================================
// 🎯 VALIDATION CHIP - Chip de validação em tempo real
// ============================================================================

class ValidationChip extends StatelessWidget {
  final String? errorMessage;
  final bool isValid;
  final bool showWhenValid;

  const ValidationChip({
    Key? key,
    this.errorMessage,
    required this.isValid,
    this.showWhenValid = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isValid && !showWhenValid) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isValid 
            ? Colors.green.shade50 
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid 
              ? Colors.green.shade300 
              : Colors.red.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 16,
            color: isValid ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isValid ? 'Válido' : (errorMessage ?? 'Inválido'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isValid ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🎨 ANIMATED SECTION HEADER - Header de seção com animação
// ============================================================================

class AnimatedSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  const AnimatedSectionHeader({
    Key? key,
    required this.title,
    required this.icon,
    required this.isExpanded,
    this.onTap,
    this.color,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? const Color(0xFFF28C38);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded 
                ? primaryColor.withOpacity(0.3) 
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: primaryColor,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}