# Laravel Pusher Beams Integration: Admin App Notification Page

This guide details how to integrate **Pusher Beams** into your Laravel backend and build a complete **Admin App Notification Page** to send real-time push notifications to your Flutter mobile app users.

---

## 1. Credentials & Configuration

### A. Environment Variables (`.env`)
Add your Pusher Beams credentials to your Laravel `.env` file:

```env
PUSHER_BEAMS_INSTANCE_ID="c144beef-40e3-468e-9b6b-3430167dec63"
PUSHER_BEAMS_SECRET_KEY="722F9A2E588EF14BEE675E6F53B3EA8AAFF83E656709151B0E7DF0A241E9FB37"
```

### B. Configuration File (`config/services.php`)
Register the keys in `config/services.php`:

```php
'pusher_beams' => [
    'instance_id' => env('PUSHER_BEAMS_INSTANCE_ID'),
    'secret_key'  => env('PUSHER_BEAMS_SECRET_KEY'),
],
```

---

## 2. Composer Dependency

Install the official Pusher Beams PHP Server SDK via Composer:

```bash
composer require pusher/pusher-push-notifications
```

---

## 3. Database Migration & Model (Notification Log)

Create a database table to keep a history of all notifications sent from the admin panel:

```bash
php artisan make:migration create_app_notifications_table
```

### Migration (`database/migrations/xxxx_xx_xx_create_app_notifications_table.php`)

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('app_notifications', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('body');
            $table->string('target')->default('all'); // all, user, or custom interest
            $table->string('target_value')->nullable(); // user_id or specific interest
            $table->string('action_url')->nullable(); // optional deep-link route
            $table->string('publish_id')->nullable(); // Pusher publishId
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_notifications');
    }
};
```

Run migration:
```bash
php artisan migrate
```

### Model (`app/Models/AppNotification.php`)

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AppNotification extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'body',
        'target',
        'target_value',
        'action_url',
        'publish_id',
        'created_by',
    ];

    public function sender()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
```

---

## 4. Push Notification Service

Create a dedicated service class to handle publishing notifications:

```bash
php artisan make:service PushNotificationService
```
*(Or create `app/Services/PushNotificationService.php` directly)*

### `app/Services/PushNotificationService.php`

```php
<?php

namespace App\Services;

use Exception;
use Illuminate\Support\Facades\Log;
use Pusher\PushNotifications\PushNotifications;

class PushNotificationService
{
    protected PushNotifications $beamsClient;

    public function __construct()
    {
        $this->beamsClient = new PushNotifications([
            'instanceId' => config('services.pusher_beams.instance_id'),
            'secretKey'  => config('services.pusher_beams.secret_key'),
        ]);
    }

    /**
     * Publish notification to one or more interests (e.g. ['hello', 'all'])
     *
     * @param array $interests
     * @param string $title
     * @param string $body
     * @param array $data Additional payload data for deep linking
     * @return string|null publishId
     */
    public function sendToInterests(array $interests, string $title, string $body, array $data = []): ?string
    {
        try {
            $response = $this->beamsClient->publishToInterests(
                $interests,
                [
                    'fcm' => [
                        'notification' => [
                            'title' => $title,
                            'body'  => $body,
                            'sound' => 'default',
                        ],
                        'data' => array_merge($data, [
                            'title'     => $title,
                            'body'      => $body,
                            'timestamp' => now()->toISOString(),
                        ]),
                    ],
                ]
            );

            return $response->publishId ?? null;
        } catch (Exception $e) {
            Log::error('Pusher Beams Publish Error: ' . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Publish notification to specific authenticated users
     *
     * @param array $userIds
     * @param string $title
     * @param string $body
     * @param array $data
     * @return string|null publishId
     */
    public function sendToUsers(array $userIds, string $title, string $body, array $data = []): ?string
    {
        try {
            $response = $this->beamsClient->publishToUsers(
                $userIds,
                [
                    'fcm' => [
                        'notification' => [
                            'title' => $title,
                            'body'  => $body,
                            'sound' => 'default',
                        ],
                        'data' => $data,
                    ],
                ]
            );

            return $response->publishId ?? null;
        } catch (Exception $e) {
            Log::error('Pusher Beams Publish to Users Error: ' . $e->getMessage());
            throw $e;
        }
    }
}
```

---

## 5. Admin Controller

Create the controller to manage the admin page and submission:

```bash
php artisan make:controller Admin/AppNotificationController
```

### `app/Http/Controllers/Admin/AppNotificationController.php`

```php
<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\User;
use App\Services\PushNotificationService;
use Illuminate\Http\Request;

class AppNotificationController extends Controller
{
    protected PushNotificationService $pushService;

    public function __construct(PushNotificationService $pushService)
    {
        $this->pushService = $pushService;
    }

    /**
     * Display the Notification Dashboard & History
     */
    public function index()
    {
        $notifications = AppNotification::with('sender')
            ->latest()
            ->paginate(15);

        // Fetch active employees/users for target dropdown
        $users = User::select('id', 'name', 'email')->get();

        return view('admin.notifications.index', compact('notifications', 'users'));
    }

    /**
     * Send push notification from the admin composer
     */
    public function send(Request $request)
    {
        $request->validate([
            'title'        => 'required|string|max:120',
            'body'         => 'required|string|max:500',
            'target'       => 'required|in:all,hello,user',
            'user_id'      => 'required_if:target,user|nullable|exists:users,id',
            'action_route' => 'nullable|string|max:100',
        ]);

        $title = $request->input('title');
        $body = $request->input('body');
        $target = $request->input('target');
        $targetValue = null;
        $publishId = null;

        $extraData = [
            'action' => $request->input('action_route') ?? 'home',
        ];

        try {
            if ($target === 'user') {
                $targetValue = $request->input('user_id');
                // Target a specific employee via their user interest: "user_{id}"
                $publishId = $this->pushService->sendToInterests(
                    ["user_{$targetValue}"],
                    $title,
                    $body,
                    $extraData
                );
            } elseif ($target === 'hello') {
                $publishId = $this->pushService->sendToInterests(
                    ['hello'],
                    $title,
                    $body,
                    $extraData
                );
            } else {
                // Send to both 'hello' and 'all' broadcast channels
                $publishId = $this->pushService->sendToInterests(
                    ['hello', 'all'],
                    $title,
                    $body,
                    $extraData
                );
            }

            // Save to database log
            AppNotification::create([
                'title'        => $title,
                'body'         => $body,
                'target'       => $target,
                'target_value' => $targetValue,
                'action_url'   => $request->input('action_route'),
                'publish_id'   => $publishId,
                'created_by'   => auth()->id(),
            ]);

            return redirect()
                ->route('admin.notifications.index')
                ->with('success', 'Notification dispatched successfully! (ID: ' . $publishId . ')');
        } catch (\Exception $e) {
            return redirect()
                ->back()
                ->withInput()
                ->with('error', 'Failed to send notification: ' . $e->getMessage());
        }
    }
}
```

---

## 6. Admin Routes (`routes/web.php`)

Add the routes inside your authenticated Admin middleware group:

```php
use App\Http\Controllers\Admin\AppNotificationController;

Route::middleware(['auth', 'admin'])->prefix('admin')->name('admin.')->group(function () {
    Route::get('/app-notifications', [AppNotificationController::class, 'index'])->name('notifications.index');
    Route::post('/app-notifications/send', [AppNotificationController::class, 'send'])->name('notifications.send');
});
```

---

## 7. Admin Blade View (`resources/views/admin/notifications/index.blade.php`)

Create the directory and blade template:
`resources/views/admin/notifications/index.blade.php`

```html
@extends('layouts.admin') {{-- Change to your admin layout --}}

@section('title', 'App Notifications')

@section('content')
<div class="container-fluid py-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
            <h3 class="fw-bold mb-1">Mobile Push Notifications</h3>
            <p class="text-muted mb-0">Compose and send real-time alerts to the Leadx mobile app.</p>
        </div>
        <span class="badge bg-success-subtle text-success border px-3 py-2">
            <i class="bi bi-broadcast me-1"></i> Pusher Beams: Connected
        </span>
    </div>

    @if(session('success'))
        <div class="alert alert-success alert-dismissible fade show" role="alert">
            <i class="bi bi-check-circle-fill me-2"></i> {{ session('success') }}
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>
    @endif

    @if(session('error'))
        <div class="alert alert-danger alert-dismissible fade show" role="alert">
            <i class="bi bi-exclamation-triangle-fill me-2"></i> {{ session('error') }}
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>
    @endif

    <div class="row g-4">
        <!-- Composer Card -->
        <div class="col-lg-7">
            <div class="card shadow-sm border-0 h-100">
                <div class="card-header bg-white py-3">
                    <h5 class="card-title mb-0 fw-semibold">
                        <i class="bi bi-send text-primary me-2"></i> Compose Notification
                    </h5>
                </div>
                <div class="card-body p-4">
                    <form action="{{ route('admin.notifications.send') }}" method="POST">
                        @csrf

                        <!-- Target Audience -->
                        <div class="mb-3">
                            <label class="form-label fw-semibold">Target Audience</label>
                            <select name="target" id="targetSelect" class="form-select @error('target') is-invalid @enderror" onchange="toggleUserSelect()">
                                <option value="hello" {{ old('target') == 'hello' ? 'selected' : '' }}>General Subscribers (Interest: 'hello')</option>
                                <option value="all" {{ old('target') == 'all' ? 'selected' : '' }}>All App Devices</option>
                                <option value="user" {{ old('target') == 'user' ? 'selected' : '' }}>Specific Employee / User</option>
                            </select>
                            @error('target') <div class="invalid-feedback">{{ $message }}</div> @enderror
                        </div>

                        <!-- Specific User Dropdown (conditional) -->
                        <div class="mb-3 d-none" id="userSelectContainer">
                            <label class="form-label fw-semibold">Select Employee / User</label>
                            <select name="user_id" class="form-select @error('user_id') is-invalid @enderror">
                                <option value="">-- Choose User --</option>
                                @foreach($users as $user)
                                    <option value="{{ $user->id }}" {{ old('user_id') == $user->id ? 'selected' : '' }}>
                                        {{ $user->name }} ({{ $user->email }})
                                    </option>
                                @endforeach
                            </select>
                            @error('user_id') <div class="invalid-feedback">{{ $message }}</div> @enderror
                        </div>

                        <!-- Title -->
                        <div class="mb-3">
                            <label class="form-label fw-semibold">Notification Title *</label>
                            <input type="text" name="title" id="notifTitle" 
                                   class="form-control @error('title') is-invalid @enderror" 
                                   placeholder="e.g. New Order Assigned" 
                                   value="{{ old('title') }}" 
                                   oninput="updatePreview()" required maxlength="120">
                            @error('title') <div class="invalid-feedback">{{ $message }}</div> @enderror
                        </div>

                        <!-- Body -->
                        <div class="mb-3">
                            <label class="form-label fw-semibold">Message Body *</label>
                            <textarea name="body" id="notifBody" rows="3" 
                                      class="form-control @error('body') is-invalid @enderror" 
                                      placeholder="e.g. You have a new pending closing approval for Order #1049." 
                                      oninput="updatePreview()" required maxlength="500">{{ old('body') }}</textarea>
                            @error('body') <div class="invalid-feedback">{{ $message }}</div> @enderror
                        </div>

                        <!-- Deep Link Route -->
                        <div class="mb-4">
                            <label class="form-label fw-semibold">On Tap Action (Optional)</label>
                            <select name="action_route" class="form-select">
                                <option value="orders">Open Orders Screen</option>
                                <option value="customers">Open Customers Screen</option>
                                <option value="follow_ups">Open Follow-ups Screen</option>
                                <option value="calendar">Open Calendar Screen</option>
                                <option value="home">Open Dashboard</option>
                            </select>
                        </div>

                        <button type="submit" class="btn btn-primary px-4 py-2 w-100 fw-semibold">
                            <i class="bi bi-send-fill me-1"></i> Dispatch Push Notification
                        </button>
                    </form>
                </div>
            </div>
        </div>

        <!-- Live Mobile Preview -->
        <div class="col-lg-5">
            <div class="card shadow-sm border-0 h-100">
                <div class="card-header bg-white py-3">
                    <h5 class="card-title mb-0 fw-semibold">
                        <i class="bi bi-phone text-muted me-2"></i> Mobile Tray Preview
                    </h5>
                </div>
                <div class="card-body d-flex align-items-center justify-content-center p-4 bg-light">
                    <!-- Phone Mockup Container -->
                    <div class="w-100" style="max-width: 320px;">
                        <div class="p-3 bg-white shadow rounded-4 border">
                            <div class="d-flex align-items-center mb-2">
                                <div class="bg-primary text-white rounded p-1 d-flex align-items-center justify-content-center me-2" style="width: 24px; height: 24px;">
                                    <small class="fw-bold">LX</small>
                                </div>
                                <span class="fw-semibold text-uppercase small text-muted">Leadx · Just now</span>
                            </div>
                            <h6 class="fw-bold mb-1 text-dark" id="previewTitle">Notification Title</h6>
                            <p class="mb-0 text-muted small" id="previewBody">Message body preview will appear here as you type...</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Notification Logs Table -->
    <div class="card shadow-sm border-0 mt-4">
        <div class="card-header bg-white py-3">
            <h5 class="card-title mb-0 fw-semibold">
                <i class="bi bi-clock-history me-2"></i> Sent Notifications History
            </h5>
        </div>
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th>Date & Time</th>
                        <th>Title & Message</th>
                        <th>Audience</th>
                        <th>Target</th>
                        <th>Publish ID</th>
                        <th>Sent By</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($notifications as $item)
                        <tr>
                            <td class="text-nowrap small text-muted">
                                {{ $item->created_at->format('d M Y, h:i A') }}
                            </td>
                            <td>
                                <strong class="d-block text-dark">{{ $item->title }}</strong>
                                <small class="text-muted text-truncate d-inline-block" style="max-width: 300px;">
                                    {{ $item->body }}
                                </small>
                            </td>
                            <td>
                                <span class="badge bg-secondary">{{ ucfirst($item->target) }}</span>
                            </td>
                            <td>
                                {{ $item->target_value ? 'ID: ' . $item->target_value : 'Broadcast' }}
                            </td>
                            <td>
                                <code class="small text-muted">{{ Str::limit($item->publish_id, 16) }}</code>
                            </td>
                            <td>
                                <small>{{ $item->sender->name ?? 'System' }}</small>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="text-center py-4 text-muted">
                                <i class="bi bi-inbox fs-3 d-block mb-2"></i>
                                No notifications dispatched yet.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        @if($notifications->hasPages())
            <div class="card-footer bg-white py-3">
                {{ $notifications->links() }}
            </div>
        @endif
    </div>
</div>

<script>
    function toggleUserSelect() {
        const target = document.getElementById('targetSelect').value;
        const container = document.getElementById('userSelectContainer');
        if (target === 'user') {
            container.classList.remove('d-none');
        } else {
            container.classList.add('d-none');
        }
    }

    function updatePreview() {
        const title = document.getElementById('notifTitle').value || 'Notification Title';
        const body = document.getElementById('notifBody').value || 'Message body preview will appear here as you type...';
        document.getElementById('previewTitle').innerText = title;
        document.getElementById('previewBody').innerText = body;
    }

    // Initialize toggle state on page load
    document.addEventListener('DOMContentLoaded', toggleUserSelect);
</script>
@endsection
```

---

## 8. Mobile App Integration (Flutter / Android)

Your Flutter app's [MainActivity.kt](file:///d:/App%20Projects/Leadx/leadx/android/app/src/main/kotlin/com/example/leadx/MainActivity.kt) is already subscribed to the interest `"hello"`:

```kotlin
PushNotifications.start(applicationContext, "c144beef-40e3-468e-9b6b-3430167dec63")
PushNotifications.addDeviceInterest("hello")
```

### Optional: Subscribing Logged-in Employees to their Private User Channel
When an employee logs into the app, you can also subscribe them to `user_{id}` so the admin can send direct 1-to-1 messages:

```kotlin
// In MainActivity or via Platform Channel upon user login:
PushNotifications.addDeviceInterest("user_" + employeeId)
```

And upon logout:
```kotlin
PushNotifications.clearDeviceInterests()
PushNotifications.addDeviceInterest("hello") // Re-subscribe to general alerts
```

---

## 9. Automated Trigger Example (e.g. In an Observer or Event)

You can also send push notifications automatically whenever events happen in Laravel:

```php
use App\Services\PushNotificationService;

public function orderCreated(Order $order, PushNotificationService $pushService)
{
    $pushService->sendToInterests(
        ['hello'],
        'New Order Created',
        "Order #{$order->order_number} for {$order->customer_name} has been placed.",
        ['order_id' => $order->id, 'action' => 'orders']
    );
}
```
