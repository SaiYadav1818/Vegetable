import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/design_components.dart';
import '../customer/customer_cart.dart';
import 'order_models.dart';
import 'orders_api.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final OrdersApi _api = OrdersApi(widget.client);
  late final CustomerCart _cart = CustomerCart(_api);
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController();
  final _address = TextEditingController(), _area = TextEditingController();
  final _pin = TextEditingController(), _house = TextEditingController();
  final _landmark = TextEditingController(),
      _instructions = TextEditingController();
  DateTime _date = DateTime.now();
  String _slot = 'MORNING';
  bool _placing = false;
  String? _checkoutIdempotencyKey;

  List<CustomerAddress> _savedAddresses = [];
  CustomerAddress? _selectedAddress;
  bool _isNewAddress = false;
  bool _saveNewAddress = false;
  String _newAddressLabel = 'Home';
  ShopSettings? _shopSettings;

  @override
  void initState() {
    super.initState();
    _checkoutIdempotencyKey = 'chk_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await _cart.load();
    } catch (_) {}

    try {
      final settings = await _api.getShopSettings();
      if (mounted) setState(() => _shopSettings = settings);
    } catch (_) {}

    try {
      final addresses = await _api.getAddresses();
      if (mounted && addresses.isNotEmpty) {
        setState(() {
          _savedAddresses = addresses;
          final defaultAddr = addresses.where((a) => a.isDefault).firstOrNull ?? addresses.first;
          _applyAddress(defaultAddr);
        });
      } else if (mounted) {
        setState(() => _isNewAddress = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isNewAddress = true);
    }
  }

  void _applyAddress(CustomerAddress address) {
    _selectedAddress = address;
    _isNewAddress = false;
    _name.text = address.recipientName;
    _phone.text = address.recipientPhone;
    _address.text = address.addressLine;
    _house.text = address.houseNumber ?? '';
    _area.text = address.area;
    _pin.text = address.pincode;
    _landmark.text = address.landmark ?? '';
  }

  void _switchToNewAddress() {
    setState(() {
      _selectedAddress = null;
      _isNewAddress = true;
      _address.clear();
      _house.clear();
      _area.clear();
      _pin.clear();
      _landmark.clear();
    });
  }

  @override
  void dispose() {
    _cart.dispose();
    for (final c in [
      _name,
      _phone,
      _address,
      _area,
      _pin,
      _house,
      _landmark,
      _instructions
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  num get _deliveryFee {
    if (_shopSettings == null) return 30;
    if (_cart.subtotal >= _shopSettings!.freeDeliveryThreshold) return 0;
    return _shopSettings!.deliveryCharge;
  }

  num get _grandTotal => _cart.subtotal + _deliveryFee;

  Future<void> _place() async {
    if (_placing || !_form.currentState!.validate() || _cart.lines.isEmpty) return;
    setState(() => _placing = true);
    try {
      if (_isNewAddress && _saveNewAddress) {
        try {
          await _api.createAddress(CustomerAddress(
            id: 0,
            label: _newAddressLabel,
            recipientName: _name.text.trim(),
            recipientPhone: _phone.text.trim(),
            addressLine: _address.text.trim(),
            houseNumber: _house.text.trim().isEmpty ? null : _house.text.trim(),
            area: _area.text.trim(),
            landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
            pincode: _pin.text.trim(),
            isDefault: _savedAddresses.isEmpty,
          ));
        } catch (_) {}
      }

      final order = await _api.placeOrder(
        idempotencyKey: _checkoutIdempotencyKey,
        cart: _cart.snapshot,
        recipientName: _name.text.trim(),
        recipientPhone: _phone.text.trim(),
        addressLine: _address.text.trim(),
        houseNumber: _house.text.trim().isEmpty ? null : _house.text.trim(),
        area: _area.text.trim(),
        pincode: _pin.text.trim(),
        landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
        deliveryInstructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
        deliveryDate: _date,
        deliverySlot: _slot,
      );
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.check_circle_rounded,
                    color: AppColors.green, size: 44),
                title: const Text('Order confirmed'),
                content: Text(
                    'Order ${order.orderNumber} is placed. Your total is ₹${order.totalAmount.toStringAsFixed(2)}. Pay in cash when the order arrives. Delivery OTP: ${order.deliveryOtp ?? 'refresh it from My Orders'}.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'))
                ],
              ));
      if (mounted) Navigator.pop(context, order);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_api.describeError(error))));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: AppColors.green, size: 20),
                const SizedBox(width: 9),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800))
              ]),
              const SizedBox(height: 12),
              ...children,
            ])),
      );

  Widget _field(TextEditingController controller, String label,
          {String? Function(String?)? validator,
          TextInputType? keyboardType,
          String? hint}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: label, hintText: hint),
              validator: validator));

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final value = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(today.year, today.month, today.day),
        lastDate: today.add(const Duration(days: 30)));
    if (value != null) setState(() => _date = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const FreshBasketAppBar(title: Text('Checkout')),
        body: _cart.loading
            ? const LoadingState(message: 'Preparing your basket...')
            : _cart.lines.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Your basket is empty',
                    message: 'Add vegetables before you check out.')
                : Form(
                    key: _form,
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
                        children: [
                          Text('Almost there',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                              'Confirm your delivery details and place your order.',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 14),

                          if (_savedAddresses.isNotEmpty) ...[
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ..._savedAddresses.map((addr) {
                                    final isSelected = !_isNewAddress && _selectedAddress?.id == addr.id;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        avatar: Icon(
                                          addr.label.toLowerCase() == 'work'
                                              ? Icons.work_outline
                                              : Icons.home_outlined,
                                          size: 16,
                                          color: isSelected ? Colors.white : AppColors.darkGreen,
                                        ),
                                        label: Text('${addr.label} (${addr.area})'),
                                        selected: isSelected,
                                        onSelected: (_) => setState(() => _applyAddress(addr)),
                                      ),
                                    );
                                  }),
                                  ChoiceChip(
                                    avatar: const Icon(Icons.add, size: 16),
                                    label: const Text('New Address'),
                                    selected: _isNewAddress,
                                    onSelected: (_) => _switchToNewAddress(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          _section(
                              'Delivery address', Icons.location_on_outlined, [
                            _field(_house, 'House / flat number',
                                hint: 'Optional'),
                            _field(_address, 'Street address',
                                validator: _required),
                            _field(_area, 'Area / city', validator: _required),
                            _field(_pin, '6 digit pincode',
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null ||
                                        !RegExp(r'^[0-9]{6}$')
                                            .hasMatch(v.trim())
                                    ? 'Enter a 6 digit pincode'
                                    : null),
                            _field(_landmark, 'Landmark', hint: 'Optional'),
                            if (_isNewAddress) ...[
                              const Divider(height: 20),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Save this address for future orders'),
                                value: _saveNewAddress,
                                onChanged: (val) => setState(() => _saveNewAddress = val ?? false),
                              ),
                              if (_saveNewAddress)
                                Row(
                                  children: ['Home', 'Work', 'Other'].map((l) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(l),
                                      selected: _newAddressLabel == l,
                                      onSelected: (_) => setState(() => _newAddressLabel = l),
                                    ),
                                  )).toList(),
                                ),
                            ],
                          ]),
                          const SizedBox(height: 10),
                          _section(
                              'Contact details', Icons.person_outline_rounded, [
                            _field(_name, 'Recipient name',
                                validator: _required),
                            _field(_phone, 'Phone number',
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null ||
                                        !RegExp(r'^[0-9+() -]{7,20}$')
                                            .hasMatch(v.trim())
                                    ? 'Enter a valid phone number'
                                    : null),
                          ]),
                          const SizedBox(height: 10),
                          _section('Delivery time', Icons.schedule_rounded, [
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                    Icons.calendar_today_outlined,
                                    color: AppColors.green),
                                title: const Text('Delivery date'),
                                subtitle: Text(
                                    '${_date.day}/${_date.month}/${_date.year}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _pickDate),
                            DropdownButtonFormField<String>(
                                initialValue: _slot,
                                decoration: const InputDecoration(
                                    labelText: 'Preferred time slot'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'MORNING', child: Text('Morning (6 AM - 9 AM)')),
                                  DropdownMenuItem(
                                      value: 'AFTERNOON',
                                      child: Text('Afternoon (12 PM - 3 PM)')),
                                  DropdownMenuItem(
                                      value: 'EVENING', child: Text('Evening (5 PM - 8 PM)'))
                                ],
                                onChanged: (value) =>
                                    setState(() => _slot = value ?? 'MORNING')),
                            const SizedBox(height: 10),
                            TextFormField(
                                controller: _instructions,
                                minLines: 1,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Delivery instructions',
                                    hintText: 'Optional')),
                          ]),
                          const SizedBox(height: 10),
                          _section('Your vegetables',
                              Icons.shopping_basket_outlined, [
                            ..._cart.lines.map((line) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(
                                          '${line.name} · ${line.quantity} ${line.unit.toLowerCase()}')),
                                  PriceText(amount: line.lineTotal)
                                ]))),
                            const Divider(height: 22),
                            _summaryRow('Subtotal', _cart.subtotal),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: Text('Delivery fee',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall)),
                              _deliveryFee == 0
                                  ? const Text('FREE',
                                      style: TextStyle(
                                          color: AppColors.green,
                                          fontWeight: FontWeight.bold))
                                  : PriceText(amount: _deliveryFee)
                            ]),
                            if (_deliveryFee > 0 && _shopSettings != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Add ₹${(_shopSettings!.freeDeliveryThreshold - _cart.subtotal).clamp(0, 9999).toStringAsFixed(0)} more for FREE delivery!',
                                  style: const TextStyle(
                                      color: AppColors.darkGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            const Divider(height: 16),
                            _summaryRow('Grand Total', _grandTotal, isTotal: true),
                          ]),
                          const SizedBox(height: 10),
                          Card(
                              color: AppColors.paleGreen,
                              child: const ListTile(
                                  leading: Icon(Icons.payments_outlined,
                                      color: AppColors.darkGreen),
                                  title: Text('Cash on delivery',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      'Pay your driver when the fresh vegetables arrive.'))),
                        ])),
        bottomNavigationBar: _cart.lines.isEmpty || _cart.loading
            ? null
            : SafeArea(
                child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppColors.line))),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Grand Total',
                                style: Theme.of(context).textTheme.bodySmall),
                            PriceText(
                                amount: _grandTotal,
                                emphasized: true,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800))
                          ])),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 2,
                          child: SizedBox(
                              height: 50,
                              child: FilledButton(
                                  onPressed: _placing ? null : _place,
                                  child: _placing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Text('Place COD order'))))
                    ]))),
      );

  Widget _summaryRow(String label, num amount, {bool isTotal = false}) => Row(children: [
        Expanded(
            child: Text(label,
                style: isTotal
                    ? const TextStyle(fontWeight: FontWeight.w800)
                    : null)),
        PriceText(amount: amount, emphasized: isTotal)
      ]);
}
